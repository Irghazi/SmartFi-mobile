import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../auth_repository.dart';

/// Implementasi Firebase Authentication & Manajemen Pengguna Aktif
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Gate untuk mencegah race condition antara authStateChanges() dan signUp()
  Completer<void>? _signUpGate;

  FirebaseAuthRepository();

  String _mapError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email atau kata sandi salah. Silakan periksa kembali.';
        case 'invalid-email':
          return 'Format alamat email tidak valid.';
        case 'email-already-in-use':
          return 'Email ini sudah terdaftar. Silakan masuk dengan akun Anda.';
        case 'weak-password':
          return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
        case 'user-disabled':
          return 'Akun ini telah dinonaktifkan.';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan gagal. Tunggu sebentar lalu coba lagi.';
        case 'network-request-failed':
          return 'Gagal terhubung ke internet. Periksa koneksi jaringan Anda.';
        case 'account-exists-with-different-credential':
          return 'Akun dengan email ini sudah terdaftar menggunakan metode masuk lain.';
        case 'web-context-canceled':
        case 'canceled':
        case 'popup-closed-by-user':
          return 'Proses masuk dengan Google dibatalkan pengguna.';
        default:
          final rawMsg = (error.message ?? '').toLowerCase();
          if (rawMsg.contains('package certificate hash') ||
              rawMsg.contains('certificate') ||
              rawMsg.contains('sha-1')) {
            return 'Login Google membutuhkan APK bertanda tangan resmi (SHA-1 terdaftar di Firebase). Gunakan APK rilis atau masuk dengan Email & Kata Sandi.';
          }
          return error.message ?? 'Terjadi kesalahan autentikasi (${error.code}).';
      }
    }
    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return 'Layanan server sedang sibuk atau offline. Coba beberapa saat lagi.';
      }
      if (error.code == 'permission-denied') {
        return 'Akses ditolak oleh server. Pastikan Anda sudah masuk dengan akun yang benar.';
      }
      return error.message ?? 'Terjadi kesalahan Firebase (${error.code}).';
    }
    if (error is PlatformException) {
      final msg = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (msg.contains('sign_in_canceled') || msg.contains('canceled')) {
        return 'Proses masuk dengan Google dibatalkan pengguna.';
      }
      if (msg.contains('network_error') || msg.contains('7:')) {
        return 'Koneksi internet bermasalah saat masuk dengan Google.';
      }
      if (msg.contains('10:') || msg.contains('sign_in_failed')) {
        return 'Gagal masuk dengan Google. Periksa koneksi internet dan coba lagi.';
      }
      return error.message ?? 'Gagal masuk dengan Google (${error.code}).';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Mendeteksi kegagalan native GoogleSignIn akibat ketidakcocokan SHA-1 (Kode 10 / 12500 / Play Services)
  /// sehingga aplikasi dapat otomatis beralih ke Firebase OAuth Web Provider yang tidak bergantung SHA-1.
  bool _shouldFallbackToWebGoogleSignIn(Object error) {
    if (error is PlatformException) {
      final msg = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (msg.contains('sign_in_canceled') || msg.contains('canceled')) {
        return false;
      }
      if (msg.contains('network_error') || msg.contains('7:')) {
        return false;
      }
      return msg.contains('10:') ||
          msg.contains('12500') ||
          msg.contains('12502') ||
          msg.contains('sign_in_failed') ||
          msg.contains('developer_error') ||
          msg.contains('apiexception');
    }
    return false;
  }

  /// Alur login Google berbasis Firebase Auth OAuth (Chrome Custom Tabs) —
  /// berjalan di SEMUA perangkat, keystore debug perangkat manapun, maupun emulator
  /// tanpa memerlukan pendaftaran SHA-1 perangkat pengembang.
  Future<AppUser> _signInWithGoogleWebProvider() async {
    final googleProvider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});

    final userCredential = await _auth.signInWithProvider(googleProvider);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Gagal mendapatkan data akun Google.');
    }
    return await _getOrFetchUserProfile(user);
  }

  AppUser _appUserFromDoc(User firebaseUser, Map<String, dynamic> data) {
    return AppUser.fromJson({
      ...data,
      'id': firebaseUser.uid,
      'email': firebaseUser.email ?? data['email'] ?? '',
      'name': (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name']
          : (firebaseUser.displayName?.trim().isNotEmpty == true
              ? firebaseUser.displayName
              : 'Pengguna SmartFi'),
      'avatarUrl': data['avatarUrl'] ?? firebaseUser.photoURL,
    });
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) return Stream<AppUser?>.value(null);

      return Stream<AppUser?>.multi((controller) async {
        try {
          final initial = await _getOrFetchUserProfile(firebaseUser);
          if (!controller.isClosed) controller.add(initial);
        } catch (_) {
          if (!controller.isClosed) {
            controller.add(AppUser(
              id: firebaseUser.uid,
              name: firebaseUser.displayName ?? 'Pengguna SmartFi',
              email: firebaseUser.email ?? '',
              targetSavings: 5000000,
              avatarUrl: firebaseUser.photoURL,
              isTrial: false,
            ));
          }
        }

        final sub = _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots()
            .listen(
          (snap) {
            if (!controller.isClosed && snap.exists && snap.data() != null) {
              controller.add(_appUserFromDoc(firebaseUser, snap.data()!));
            }
          },
          onError: (_) {},
        );

        controller.onCancel = sub.cancel;
      });
    });
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _getOrFetchUserProfile(firebaseUser);
  }

  Future<AppUser> _getOrFetchUserProfile(User firebaseUser) async {
    final pendingGate = _signUpGate;
    if (pendingGate != null && !pendingGate.isCompleted) {
      await pendingGate.future;
      await firebaseUser.reload().catchError((_) {});
    }

    final refreshedUser = _auth.currentUser ?? firebaseUser;
    final userDocRef = _firestore.collection('users').doc(refreshedUser.uid);
    DocumentSnapshot<Map<String, dynamic>>? docSnapshot;

    try {
      docSnapshot = await userDocRef.get().timeout(const Duration(seconds: 4));
    } catch (_) {
      try {
        docSnapshot = await userDocRef.get(const GetOptions(source: Source.cache));
      } catch (_) {}
    }

    if (docSnapshot != null && docSnapshot.exists && docSnapshot.data() != null) {
      return _appUserFromDoc(refreshedUser, docSnapshot.data()!);
    }

    if (docSnapshot == null) {
      return AppUser(
        id: refreshedUser.uid,
        name: refreshedUser.displayName ?? 'Pengguna SmartFi',
        email: refreshedUser.email ?? '',
        targetSavings: 5000000,
        reminderEnabled: false,
        reminderTime: '08:00',
        reminderTimezone: 'Asia/Jakarta',
        avatarUrl: refreshedUser.photoURL,
        isTrial: false,
      );
    }

    return _initializeNewUser(
      uid: refreshedUser.uid,
      name: (refreshedUser.displayName?.trim().isNotEmpty == true)
          ? refreshedUser.displayName!.trim()
          : 'Pengguna SmartFi',
      email: refreshedUser.email ?? '',
      avatarUrl: refreshedUser.photoURL,
    );
  }

  /// Membuat profil pengguna dan kategori bawaan dalam satu batched write (idempoten)
  Future<AppUser> _initializeNewUser({
    required String uid,
    required String name,
    required String email,
    String? avatarUrl,
  }) async {
    final userDocRef = _firestore.collection('users').doc(uid);
    try {
      final existing = await userDocRef.get().timeout(const Duration(seconds: 3));
      if (existing.exists && existing.data() != null) {
        return AppUser.fromJson({...existing.data()!, 'id': uid});
      }
    } catch (_) {}

    final batch = _firestore.batch();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Pengguna SmartFi';

    final userData = {
      'id': uid,
      'name': cleanName,
      'email': email,
      'targetSavings': 5000000,
      'reminderEnabled': false,
      'reminderTime': '08:00',
      'reminderTimezone': 'Asia/Jakarta',
      'avatarUrl': avatarUrl,
      'isTrial': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    // 1. Buat dokumen user
    batch.set(userDocRef, userData, SetOptions(merge: true));

    // 2. Buat kategori default dengan ID deterministik agar tidak pernah duplikat
    final categoriesCol = userDocRef.collection('categories');
    for (final defCat in CategoryModel.defaultCategories) {
      final catDoc = categoriesCol.doc(defCat.id);
      batch.set(
        catDoc,
        {
          'id': defCat.id,
          'userId': uid,
          'name': defCat.name,
          'type': defCat.type,
          'iconName': defCat.iconName,
          'colorHex': defCat.colorHex,
          'isDefault': true,
          'createdAt': Timestamp.fromDate(defCat.createdAt),
        },
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit().timeout(const Duration(seconds: 2));
    } catch (_) {}

    return AppUser(
      id: uid,
      name: cleanName,
      email: email,
      targetSavings: 5000000,
      reminderEnabled: false,
      reminderTime: '08:00',
      reminderTimezone: 'Asia/Jakarta',
      avatarUrl: avatarUrl,
      isTrial: false,
    );
  }

  @override
  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      return await _getOrFetchUserProfile(user);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Proses masuk dengan Google dibatalkan pengguna.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        debugPrint('GoogleSignIn token kosong, beralih ke Firebase OAuth Web Provider.');
        return await _signInWithGoogleWebProvider();
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      return await _getOrFetchUserProfile(user);
    } catch (e) {
      if (_shouldFallbackToWebGoogleSignIn(e)) {
        debugPrint(
          'Native GoogleSignIn gagal ($e), otomatis beralih ke Firebase OAuth Web Provider.',
        );
        try {
          await _googleSignIn.signOut().catchError((_) => null);
          return await _signInWithGoogleWebProvider();
        } catch (webErr) {
          throw Exception(_mapError(webErr));
        }
      }
      throw Exception(_mapError(e));
    }
  }

  @override
  Future<AppUser> signUp(String name, String email, String password) async {
    final gate = Completer<void>();
    _signUpGate = gate;
    try {
      final cleanName = name.trim().isNotEmpty ? name.trim() : 'Pengguna SmartFi';
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(cleanName);

      return await _initializeNewUser(
        uid: user.uid,
        name: cleanName,
        email: email.trim(),
      );
    } catch (e) {
      throw Exception(_mapError(e));
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (identical(_signUpGate, gate)) _signUpGate = null;
    }
  }

  @override
  Future<void> updateProfile({
    String? name,
    int? targetSavings,
    bool? reminderEnabled,
    String? reminderTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }

    try {
      final updates = <String, dynamic>{
        'id': user.uid,
        'email': user.email ?? '',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null && name.trim().isNotEmpty) {
        // Jalankan updateDisplayName dengan timeout singkat agar tidak memblokir saat koneksi lambat
        try {
          await user.updateDisplayName(name.trim()).timeout(const Duration(seconds: 2));
        } catch (_) {}
        updates['name'] = name.trim();
      }
      if (targetSavings != null) {
        updates['targetSavings'] = targetSavings;
      }
      if (reminderEnabled != null) {
        updates['reminderEnabled'] = reminderEnabled;
      }
      if (reminderTime != null) {
        updates['reminderTime'] = reminderTime;
      }

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(updates, SetOptions(merge: true))
            .timeout(const Duration(milliseconds: 900));
      } on TimeoutException {
        // Tersimpan di cache lokal Firestore & akan disinkronkan otomatis ke cloud
      }
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
