import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/dummy/dummy_transaction_repository.dart';
import '../../../data/repositories/firebase/firebase_transaction_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/providers/auth_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseTransactionRepository();
  }
  return DummyTransactionRepository();
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repository;
  final String? _userId;

  TransactionsNotifier(this._repository, this._userId)
      : super(_userId == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_userId != null) {
      loadTransactions();
    }
  }

  Future<void> loadTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    bool showLoading = true,
  }) async {
    final uid = _userId;
    if (uid == null) {
      if (mounted) state = const AsyncValue.data([]);
      return;
    }

    if (showLoading && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _repository.getTransactions(
        uid,
        startDate: startDate,
        endDate: endDate,
        type: type,
      );
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, st);
      } else {
        rethrow;
      }
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    await _repository.addTransaction(tx);
    await loadTransactions(showLoading: false);
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _repository.updateTransaction(tx);
    await loadTransactions(showLoading: false);
  }

  Future<void> deleteTransaction(String txId) async {
    await _repository.deleteTransaction(txId);
    await loadTransactions(showLoading: false);
  }

  Future<void> deleteByRange(String range) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }
    await _repository.deleteTransactionsByRange(uid, range);
    await loadTransactions(showLoading: false);
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final userId = ref.watch(authStateProvider.select((s) => s.asData?.value?.id));

  return TransactionsNotifier(repo, userId);
});
