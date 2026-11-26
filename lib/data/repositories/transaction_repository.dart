import '../models/transaction_model.dart';

abstract class TransactionRepository {
  Future<List<TransactionModel>> getTransactions(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  });

  /// Stream real-time transaksi (opsional, diimplementasikan oleh Cloud Firestore)
  Stream<List<TransactionModel>>? watchTransactions(String userId) => null;

  Future<TransactionModel> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String transactionId);
  Future<void> deleteTransactionsByRange(String userId, String range);
}
