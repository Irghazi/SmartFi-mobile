import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/spending_anomaly_detector.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/dummy/dummy_transaction_repository.dart';
import '../../../data/repositories/firebase/firebase_transaction_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseTransactionRepository();
  }
  return DummyTransactionRepository();
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repository;
  final String? _userId;
  final Ref? _ref;
  StreamSubscription<List<TransactionModel>>? _streamSub;

  TransactionsNotifier(this._repository, this._userId, [this._ref])
      : super(_userId == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_userId != null) {
      _subscribeOrLoad(_userId);
    }
  }

  void _subscribeOrLoad(String uid) {
    final stream = _repository.watchTransactions(uid);
    if (stream != null) {
      _streamSub = stream.listen(
        (list) {
          if (mounted) state = AsyncValue.data(list);
        },
        onError: (Object err, StackTrace st) {
          if (mounted && !state.hasValue) {
            state = AsyncValue.error(err, st);
          }
        },
      );
    } else {
      loadTransactions();
    }
  }

  List<TransactionModel> _sorted(List<TransactionModel> list) {
    final copy = List<TransactionModel>.from(list);
    copy.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return copy;
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

  void _evaluateAnomalyForTransaction(
    TransactionModel tx,
    List<TransactionModel> updatedList,
  ) {
    if (!tx.isExpense) return;
    if (!SpendingAnomalyDetector.isSameCalendarDay(tx.transactionDate, DateTime.now())) {
      return;
    }

    final settings = _ref?.read(settingsProvider);
    if (settings != null && !settings.isAnomalyAlertEnabled) return;

    final result = SpendingAnomalyDetector.detect(
      transactions: updatedList,
      dailyLimit: settings?.dailySpendingLimit ?? 0,
    );

    if (result.isAnomaly) {
      unawaited(
        NotificationService().showSpendingAnomalyAlert(
          title: result.title,
          body: result.message,
          todayExpense: result.todayExpense,
        ),
      );
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final previous = state.asData?.value ?? const <TransactionModel>[];

    // Optimistic update instan agar seluruh halaman langsung menampilkan hasil tanpa perlu refresh
    final optimisticList = _sorted([tx, ...previous]);
    if (mounted) {
      state = AsyncValue.data(optimisticList);
    }

    try {
      final saved = await _repository.addTransaction(tx);
      if (mounted) {
        final current = state.asData?.value ?? optimisticList;
        final reconciled = _sorted([
          saved,
          ...current.where((t) => t.id != tx.id && t.id != saved.id),
        ]);
        state = AsyncValue.data(reconciled);
        _evaluateAnomalyForTransaction(saved, reconciled);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    final previous = state.asData?.value ?? const <TransactionModel>[];
    final optimisticList = _sorted(
      previous.map((item) => item.id == tx.id ? tx : item).toList(),
    );

    if (mounted) {
      state = AsyncValue.data(optimisticList);
    }

    try {
      await _repository.updateTransaction(tx);
      _evaluateAnomalyForTransaction(tx, optimisticList);
    } catch (e) {
      if (mounted) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  Future<void> deleteTransaction(String txId) async {
    final previous = state.asData?.value ?? const <TransactionModel>[];
    final optimisticList = previous.where((t) => t.id != txId).toList();

    if (mounted) {
      state = AsyncValue.data(optimisticList);
    }

    try {
      await _repository.deleteTransaction(txId);
    } catch (e) {
      if (mounted) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  Future<void> deleteByRange(String range) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    final previous = state.asData?.value ?? const <TransactionModel>[];
    final now = DateTime.now();
    List<TransactionModel> optimisticList;
    if (range == 'all') {
      optimisticList = const [];
    } else if (range == 'this_month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      optimisticList = previous
          .where((tx) => tx.transactionDate.isBefore(startOfMonth))
          .toList();
    } else if (range == 'this_year') {
      final startOfYear = DateTime(now.year, 1, 1);
      optimisticList = previous
          .where((tx) => tx.transactionDate.isBefore(startOfYear))
          .toList();
    } else {
      optimisticList = previous;
    }

    if (mounted) {
      state = AsyncValue.data(optimisticList);
    }

    try {
      await _repository.deleteTransactionsByRange(uid, range);
    } catch (e) {
      if (mounted) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  /// Sinkronisasi nama kategori secara instan di memori saat kategori diubah
  void renameCategoryLocally(String categoryId, String newName) {
    final current = state.asData?.value;
    if (current == null || current.isEmpty) return;
    final updated = current
        .map((tx) => tx.categoryId == categoryId
            ? tx.copyWith(categoryName: newName)
            : tx)
        .toList();
    if (mounted) {
      state = AsyncValue.data(updated);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final userId = ref.watch(authStateProvider.select((s) => s.asData?.value?.id));

  return TransactionsNotifier(repo, userId, ref);
});

/// Provider reaktif status anomali pengeluaran hari ini (dipakai Dashboard & NeoAppBar)
final dailyAnomalyProvider = Provider<SpendingAnomalyResult>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.isAnomalyAlertEnabled) {
    return const SpendingAnomalyResult.none();
  }
  final txs = ref.watch(transactionsProvider).asData?.value ?? const [];
  return SpendingAnomalyDetector.detect(
    transactions: txs,
    dailyLimit: settings.dailySpendingLimit,
  );
});
