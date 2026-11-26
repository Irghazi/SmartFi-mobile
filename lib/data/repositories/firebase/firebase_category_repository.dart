import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart';
import '../category_repository.dart';

/// Implementasi Cloud Firestore untuk Penyimpanan Kategori Transaksi Pengguna
/// Menggunakan real-time snapshots + local-first commit agar perubahan langsung tampil.
class FirebaseCategoryRepository implements CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Duration _fastWriteAckTimeout = Duration(milliseconds: 900);
  static const Duration _readTimeout = Duration(seconds: 4);

  String? _resolveUserId(String passedUserId) {
    if (passedUserId.isNotEmpty && passedUserId != 'default_user') {
      return passedUserId;
    }
    return _auth.currentUser?.uid;
  }

  Future<void> _commitFast(Future<void> writeOperation) async {
    try {
      await writeOperation.timeout(_fastWriteAckTimeout);
    } on TimeoutException {
      // Sudah tertulis di cache lokal Firestore dan akan sinkron otomatis ke server.
    }
  }

  List<CategoryModel> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel.fromJson({...data, 'id': doc.id});
    }).toList();
  }

  @override
  Stream<List<CategoryModel>>? watchCategories(String userId) {
    final uid = _resolveUserId(userId);
    if (uid == null) return null;

    var seeded = false;
    final col = _firestore.collection('users').doc(uid).collection('categories');

    return col.orderBy('createdAt', descending: false).snapshots().map((snap) {
      if (snap.docs.isEmpty && !seeded) {
        seeded = true;
        unawaited(seedDefaultCategories(uid).catchError((_) {}));
        return CategoryModel.defaultCategories
            .map((c) => c.copyWith(userId: uid))
            .toList();
      }
      return _mapSnapshot(snap);
    });
  }

  @override
  Future<List<CategoryModel>> getCategories(String userId) async {
    final uid = _resolveUserId(userId);
    if (uid == null) return [];

    final col = _firestore.collection('users').doc(uid).collection('categories');
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await col.orderBy('createdAt', descending: false).get().timeout(_readTimeout);
    } catch (_) {
      snapshot = await col
          .orderBy('createdAt', descending: false)
          .get(const GetOptions(source: Source.cache));
    }

    if (snapshot.docs.isEmpty) {
      await seedDefaultCategories(uid);
      return CategoryModel.defaultCategories
          .map((c) => c.copyWith(userId: uid))
          .toList();
    }

    return _mapSnapshot(snapshot);
  }

  @override
  Future<CategoryModel> addCategory(CategoryModel category) async {
    final uid = _resolveUserId(category.userId);
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }
    final col = _firestore.collection('users').doc(uid).collection('categories');
    final docRef = col.doc();

    final data = {
      'id': docRef.id,
      'userId': uid,
      'name': category.name,
      'type': category.type,
      'iconName': category.iconName,
      'colorHex': category.colorHex,
      'isDefault': false,
      'createdAt': Timestamp.fromDate(category.createdAt),
    };

    await _commitFast(docRef.set(data));
    return category.copyWith(id: docRef.id, userId: uid);
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    final uid = _resolveUserId(category.userId);
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }
    final userDoc = _firestore.collection('users').doc(uid);
    final docRef = userDoc.collection('categories').doc(category.id);

    final data = {
      'name': category.name,
      'type': category.type,
      'iconName': category.iconName,
      'colorHex': category.colorHex,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    await _commitFast(docRef.update(data));

    // Sinkronkan nama kategori pada transaksi terkait di latar belakang agar UI tidak tertahan
    unawaited(_syncCategoryNameToTransactions(userDoc, category));
  }

  Future<void> _syncCategoryNameToTransactions(
    DocumentReference<Map<String, dynamic>> userDoc,
    CategoryModel category,
  ) async {
    try {
      final txSnap = await userDoc
          .collection('transactions')
          .where('categoryId', isEqualTo: category.id)
          .get();

      if (txSnap.docs.isNotEmpty) {
        const batchLimit = 500;
        for (int i = 0; i < txSnap.docs.length; i += batchLimit) {
          final end = (i + batchLimit < txSnap.docs.length)
              ? i + batchLimit
              : txSnap.docs.length;
          final batch = _firestore.batch();
          for (final doc in txSnap.docs.sublist(i, end)) {
            batch.update(doc.reference, {'categoryName': category.name});
          }
          await batch.commit();
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId);

    try {
      final snapshot = await docRef
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => docRef.get().timeout(_readTimeout));
      if (snapshot.exists && snapshot.data()?['isDefault'] == true) {
        throw Exception('Kategori bawaan tidak dapat dihapus.');
      }
    } catch (e) {
      if (e.toString().contains('Kategori bawaan')) rethrow;
    }

    await _commitFast(docRef.delete());
  }

  Future<void> seedDefaultCategories(String userId) async {
    final col = _firestore.collection('users').doc(userId).collection('categories');
    try {
      final existing = await col.limit(1).get().timeout(_readTimeout);
      if (existing.docs.isNotEmpty) return; // Mencegah duplikasi
    } catch (_) {}

    final batch = _firestore.batch();
    for (final defCat in CategoryModel.defaultCategories) {
      final docRef = col.doc(defCat.id);
      final data = {
        'id': defCat.id,
        'userId': userId,
        'name': defCat.name,
        'type': defCat.type,
        'iconName': defCat.iconName,
        'colorHex': defCat.colorHex,
        'isDefault': true,
        'createdAt': Timestamp.fromDate(defCat.createdAt),
      };
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await _commitFast(batch.commit());
  }
}
