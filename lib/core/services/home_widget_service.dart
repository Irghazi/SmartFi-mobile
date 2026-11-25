import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/transaction_model.dart';
import '../utils/currency_formatter.dart';

/// Ringkasan data finansial yang dikirim ke Android Home Screen Widget 4x2
class HomeWidgetSummary {
  final bool isLoggedIn;
  final String balanceText;
  final String incomeMonthText;
  final String expenseMonthText;
  final int targetPercent;
  final bool isDark;

  const HomeWidgetSummary({
    required this.isLoggedIn,
    required this.balanceText,
    required this.incomeMonthText,
    required this.expenseMonthText,
    required this.targetPercent,
    required this.isDark,
  });

  factory HomeWidgetSummary.fromTransactions({
    required List<TransactionModel> transactions,
    required int savingsTarget,
    required bool isLoggedIn,
    required bool isDark,
    DateTime? now,
  }) {
    if (!isLoggedIn) {
      return HomeWidgetSummary(
        isLoggedIn: false,
        balanceText: 'Rp 0',
        incomeMonthText: '-',
        expenseMonthText: '-',
        targetPercent: 0,
        isDark: isDark,
      );
    }

    final refDate = now ?? DateTime.now();
    final totalIncome = transactions
        .where((t) => t.isIncome)
        .fold<int>(0, (sum, t) => sum + t.nominal);
    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold<int>(0, (sum, t) => sum + t.nominal);
    final balance = totalIncome - totalExpense;

    final monthTxs = transactions.where(
      (t) =>
          t.transactionDate.month == refDate.month &&
          t.transactionDate.year == refDate.year,
    );
    final incomeMonth = monthTxs
        .where((t) => t.isIncome)
        .fold<int>(0, (sum, t) => sum + t.nominal);
    final expenseMonth = monthTxs
        .where((t) => t.isExpense)
        .fold<int>(0, (sum, t) => sum + t.nominal);

    final target = savingsTarget > 0 ? savingsTarget : 5000000;
    final progress = balance > 0 ? (balance / target).clamp(0.0, 1.0) : 0.0;

    return HomeWidgetSummary(
      isLoggedIn: true,
      balanceText: CurrencyFormatter.formatRupiah(balance),
      incomeMonthText: CurrencyFormatter.formatRupiah(incomeMonth),
      expenseMonthText: CurrencyFormatter.formatRupiah(expenseMonth),
      targetPercent: (progress * 100).toInt(),
      isDark: isDark,
    );
  }

  Map<String, dynamic> toMap() => {
        'isLoggedIn': isLoggedIn,
        'balanceText': balanceText,
        'incomeMonthText': incomeMonthText,
        'expenseMonthText': expenseMonthText,
        'targetPercent': targetPercent,
        'isDark': isDark,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeWidgetSummary &&
        other.isLoggedIn == isLoggedIn &&
        other.balanceText == balanceText &&
        other.incomeMonthText == incomeMonthText &&
        other.expenseMonthText == expenseMonthText &&
        other.targetPercent == targetPercent &&
        other.isDark == isDark;
  }

  @override
  int get hashCode => Object.hash(
        isLoggedIn,
        balanceText,
        incomeMonthText,
        expenseMonthText,
        targetPercent,
        isDark,
      );
}

/// Jembatan sinkronisasi data & deep-link tab antara Flutter dan Widget Beranda Android 4x2
class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.smartfi.mobile/home_widget');

  HomeWidgetSummary? _lastSynced;
  bool _handlerRegistered = false;

  Future<void> syncWidget(HomeWidgetSummary summary) async {
    if (_lastSynced == summary) return;
    _lastSynced = summary;

    try {
      await _channel.invokeMethod('updateWidget', summary.toMap());
    } on MissingPluginException {
      // Aman diabaikan pada platform non-Android atau unit test
    } catch (e) {
      debugPrint('Gagal menyinkronkan widget beranda: $e');
    }
  }

  /// Mendengarkan aksi ketuk tombol pintas widget (Beranda / + Catat / Mentor AI)
  Future<void> initDeepLinkHandler(void Function(int tabIndex) onOpenTab) async {
    if (!_handlerRegistered) {
      _handlerRegistered = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onOpenTab') {
          final tabIndex = (call.arguments as num?)?.toInt();
          if (tabIndex != null && tabIndex >= 0 && tabIndex <= 4) {
            onOpenTab(tabIndex);
          }
        }
      });
    }

    try {
      final initialTab = await _channel.invokeMethod<int>('consumeInitialTabIndex');
      if (initialTab != null && initialTab >= 0 && initialTab <= 4) {
        onOpenTab(initialTab);
      }
    } on MissingPluginException {
      // Aman diabaikan pada platform non-Android atau unit test
    } catch (e) {
      debugPrint('Gagal membaca initial tab widget: $e');
    }
  }
}
