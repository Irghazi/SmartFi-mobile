import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart';
import '../category_repository.dart';

/// Implementasi Cloud Firestore untuk Penyimpanan Kategori Transaksi Pengguna
class FirebaseCategoryRepository implements CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _resolveUserId(String passedUserId) {
    if (passedUserId.isNotEmpty && passedUserId != 'default_user') {
      return passedUserId;
    }
    return _auth.currentUser?.uid;
  }

  @override
  Future<List<CategoryModel>> getCategories(String userId) async {
    final uid = _resolveUserId(userId);
    if (uid == null) return [];

    final col = _firestore.collection('users').doc(uid).collection('categories');
    final snapshot = await col.orderBy('createdAt', descending: false).get();

    if (snapshot.docs.isEmpty) {
      await seedDefaultCategories(uid);
      final refetched = await col.orderBy('createdAt', descending: false).get();
      return refetched.docs.map((doc) {
        final data = doc.data();
        return CategoryModel.fromJson({...data, 'id': doc.id});
      }).toList();
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel.fromJson({...data, 'id': doc.id});
    }).toList();
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
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
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
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(data);

    // Sinkronkan nama kategori pada transaksi terkait agar grafik dan riwayat tetap akurat
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

    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data()?['isDefault'] == true) {
      throw Exception('Kategori bawaan tidak dapat dihapus.');
    }

    await docRef.delete();
  }

  Future<void> seedDefaultCategories(String userId) async {
    final col = _firestore.collection('users').doc(userId).collection('categories');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return; // Mencegah duplikasi

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
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
