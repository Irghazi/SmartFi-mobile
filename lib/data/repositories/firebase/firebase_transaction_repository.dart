import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/transaction_model.dart';
import '../transaction_repository.dart';

/// Implementasi Cloud Firestore untuk Penyimpanan Transaksi Pengguna
/// Menggunakan local-first persistence + real-time snapshots agar UI selalu responsif instan.
class FirebaseTransactionRepository implements TransactionRepository {
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

  /// Firestore dengan offline persistence langsung menulis ke cache lokal & memicu
  /// `snapshots()` secara instan (<10ms). Timeout singkat mencegah UI macet saat sinyal lambat/offline.
  Future<void> _commitFast(Future<void> writeOperation) async {
    try {
      await writeOperation.timeout(_fastWriteAckTimeout);
    } on TimeoutException {
      // Sudah tersimpan di cache lokal Firestore dan akan sinkron otomatis ke server.
    }
  }

  List<TransactionModel> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    final list = snapshot.docs.map((doc) {
      return TransactionModel.fromJson({
        ...doc.data(),
        'id': doc.id,
        'userId': uid,
      });
    }).toList();
    list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return list;
  }

  @override
  Stream<List<TransactionModel>>? watchTransactions(String userId) {
    final uid = _resolveUserId(userId);
    if (uid == null) return null;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snap) => _mapSnapshot(snap, uid));
  }

  @override
  Future<List<TransactionModel>> getTransactions(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    final uid = _resolveUserId(userId);
    if (uid == null) return [];

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('transactionDate', descending: true);

    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      query = query.where('transactionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999, 999);
      query = query.where('transactionDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    if (type != null && type != 'all') {
      query = query.where('type', isEqualTo: type);
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get().timeout(_readTimeout);
    } catch (_) {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }

    return _mapSnapshot(snapshot, uid);
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    final uid = _resolveUserId(transaction.userId);
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }
    if (transaction.nominal <= 0) {
      throw Exception('Nominal transaksi harus lebih dari Rp 0.');
    }

    final col = _firestore.collection('users').doc(uid).collection('transactions');
    final docRef = col.doc();

    final data = {
      'id': docRef.id,
      'userId': uid,
      'type': transaction.type,
      'nominal': transaction.nominal,
      'description': transaction.description,
      'categoryId': transaction.categoryId,
      'categoryName': transaction.categoryName,
      'transactionDate': Timestamp.fromDate(transaction.transactionDate),
      'createdAt': Timestamp.fromDate(transaction.createdAt),
    };

    await _commitFast(docRef.set(data));
    return transaction.copyWith(id: docRef.id, userId: uid);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    final uid = _resolveUserId(transaction.userId);
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }
    if (transaction.nominal <= 0) {
      throw Exception('Nominal transaksi harus lebih dari Rp 0.');
    }

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transaction.id);

    final data = {
      'id': transaction.id,
      'userId': uid,
      'type': transaction.type,
      'nominal': transaction.nominal,
      'description': transaction.description,
      'categoryId': transaction.categoryId,
      'categoryName': transaction.categoryName,
      'transactionDate': Timestamp.fromDate(transaction.transactionDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    await _commitFast(docRef.set(data, SetOptions(merge: true)));
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId);

    await _commitFast(docRef.delete());
  }

  @override
  Future<void> deleteTransactionsByRange(String userId, String range) async {
    final uid = _resolveUserId(userId);
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan masuk kembali.');
    }
    final col = _firestore.collection('users').doc(uid).collection('transactions');

    Query<Map<String, dynamic>> query = col;
    final now = DateTime.now();

    if (range == 'this_month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      query = query.where('transactionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth));
    } else if (range == 'this_year') {
      final startOfYear = DateTime(now.year, 1, 1);
      query = query.where('transactionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear));
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get().timeout(_readTimeout);
    } catch (_) {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }
    if (snapshot.docs.isEmpty) return;

    const batchLimit = 500;
    for (int i = 0; i < snapshot.docs.length; i += batchLimit) {
      final end = (i + batchLimit < snapshot.docs.length)
          ? i + batchLimit
          : snapshot.docs.length;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await _commitFast(batch.commit());
    }
  }

  Future<int> getCurrentBalance(String userId) async {
    final txs = await getTransactions(userId);
    final inc = txs.where((t) => t.isIncome).fold<int>(0, (total, t) => total + t.nominal);
    final exp = txs.where((t) => t.isExpense).fold<int>(0, (total, t) => total + t.nominal);
    return inc - exp;
  }
}
