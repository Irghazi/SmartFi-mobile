import '../../data/models/transaction_model.dart';
import '../utils/currency_formatter.dart';

enum AnomalySeverity {
  none,
  warning,
  critical,
}

class SpendingAnomalyResult {
  final bool isAnomaly;
  final AnomalySeverity severity;
  final String reason; // 'none' | 'daily_limit' | 'statistical_spike' | 'monthly_income_ratio'
  final int todayExpense;
  final int baselineDailyAverage;
  final int dailyLimit;
  final double ratio;
  final String topCategoryToday;
  final int topCategoryAmountToday;
  final String title;
  final String message;

  const SpendingAnomalyResult({
    required this.isAnomaly,
    required this.severity,
    required this.reason,
    required this.todayExpense,
    required this.baselineDailyAverage,
    required this.dailyLimit,
    required this.ratio,
    required this.topCategoryToday,
    required this.topCategoryAmountToday,
    required this.title,
    required this.message,
  });

  const SpendingAnomalyResult.none({
    this.todayExpense = 0,
    this.baselineDailyAverage = 0,
    this.dailyLimit = 0,
  })  : isAnomaly = false,
        severity = AnomalySeverity.none,
        reason = 'none',
        ratio = 0,
        topCategoryToday = '',
        topCategoryAmountToday = 0,
        title = '',
        message = '';
}

/// Pendeteksi anomali pengeluaran harian yang terlalu besar.
/// Mendukung:
/// 1. Batas pengeluaran harian kustom dari pengguna (`dailyLimit > 0`)
/// 2. Deteksi lonjakan statistik otomatis terhadap rata-rata harian 30 hari terakhir (`>= 2x`)
/// 3. Fallback rasio pemasukan bulanan untuk pengguna baru (`>= 30%` pemasukan bulan ini dalam 1 hari)
class SpendingAnomalyDetector {
  SpendingAnomalyDetector._();

  static const int minSignificantDailyExpense = 50000;
  static const int minNewUserDailyExpense = 100000;
  static const int minHistoricalDays = 3;

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatRatio(double ratio) {
    return ratio.toStringAsFixed(1).replaceAll('.', ',');
  }

  static SpendingAnomalyResult detect({
    required List<TransactionModel> transactions,
    int dailyLimit = 0,
    double spikeMultiplier = 2.0,
    DateTime? now,
  }) {
    final refDate = now ?? DateTime.now();
    final todayStart = DateTime(refDate.year, refDate.month, refDate.day);
    final historyWindowStart = todayStart.subtract(const Duration(days: 30));

    // 1. Hitung total pengeluaran hari ini & kategori penyumbang terbesar hari ini
    int todayExpense = 0;
    final todayCatTotals = <String, int>{};

    for (final tx in transactions) {
      if (!tx.isExpense) continue;
      if (isSameCalendarDay(tx.transactionDate, refDate)) {
        todayExpense += tx.nominal;
        todayCatTotals[tx.categoryName] =
            (todayCatTotals[tx.categoryName] ?? 0) + tx.nominal;
      }
    }

    if (todayExpense <= 0) {
      return SpendingAnomalyResult.none(dailyLimit: dailyLimit);
    }

    String topCatName = 'Lainnya';
    int topCatAmount = 0;
    todayCatTotals.forEach((cat, amt) {
      if (amt > topCatAmount) {
        topCatAmount = amt;
        topCatName = cat;
      }
    });

    // 2. Hitung rata-rata pengeluaran harian historis (30 hari terakhir sebelum hari ini)
    final dailyHistoryTotals = <String, int>{};
    for (final tx in transactions) {
      if (!tx.isExpense) continue;
      final txDay = DateTime(
        tx.transactionDate.year,
        tx.transactionDate.month,
        tx.transactionDate.day,
      );
      if (!txDay.isBefore(historyWindowStart) && txDay.isBefore(todayStart)) {
        final key = '${txDay.year}-${txDay.month}-${txDay.day}';
        dailyHistoryTotals[key] = (dailyHistoryTotals[key] ?? 0) + tx.nominal;
      }
    }

    final int baselineDailyAverage = dailyHistoryTotals.length >= minHistoricalDays
        ? (dailyHistoryTotals.values.fold<int>(0, (s, v) => s + v) /
                dailyHistoryTotals.length)
            .round()
        : 0;

    final formattedToday = CurrencyFormatter.formatRupiah(todayExpense);
    final formattedTopCat = CurrencyFormatter.formatRupiah(topCatAmount);

    // 3. Aturan A: Melebihi batas harian kustom pengguna
    if (dailyLimit > 0 && todayExpense > dailyLimit) {
      final ratio = todayExpense / dailyLimit;
      final severity = ratio >= 1.5
          ? AnomalySeverity.critical
          : AnomalySeverity.warning;
      final formattedLimit = CurrencyFormatter.formatRupiah(dailyLimit);

      return SpendingAnomalyResult(
        isAnomaly: true,
        severity: severity,
        reason: 'daily_limit',
        todayExpense: todayExpense,
        baselineDailyAverage: baselineDailyAverage,
        dailyLimit: dailyLimit,
        ratio: ratio,
        topCategoryToday: topCatName,
        topCategoryAmountToday: topCatAmount,
        title: severity == AnomalySeverity.critical
            ? 'Pengeluaran Hari Ini Melonjak Drastis!'
            : 'Pengeluaran Melebihi Batas Harian',
        message:
            'Pengeluaran hari ini ($formattedToday) melampaui batas harianmu ($formattedLimit). Terbesar di kategori $topCatName ($formattedTopCat).',
      );
    }

    // 4. Aturan B: Deteksi lonjakan otomatis dibanding rata-rata harian 30 hari terakhir
    if (baselineDailyAverage > 0 &&
        todayExpense >= minSignificantDailyExpense &&
        todayExpense >= (baselineDailyAverage * spikeMultiplier).round()) {
      final ratio = todayExpense / baselineDailyAverage;
      final severity = ratio >= 3.0
          ? AnomalySeverity.critical
          : AnomalySeverity.warning;
      final formattedAvg = CurrencyFormatter.formatRupiah(baselineDailyAverage);

      return SpendingAnomalyResult(
        isAnomaly: true,
        severity: severity,
        reason: 'statistical_spike',
        todayExpense: todayExpense,
        baselineDailyAverage: baselineDailyAverage,
        dailyLimit: dailyLimit,
        ratio: ratio,
        topCategoryToday: topCatName,
        topCategoryAmountToday: topCatAmount,
        title: severity == AnomalySeverity.critical
            ? 'Lonjakan Pengeluaran Harian Ekstrem!'
            : 'Pengeluaran Hari Ini Terlalu Besar',
        message:
            'Pengeluaran hari ini ($formattedToday) mencapai ${_formatRatio(ratio)}x rata-rata harianmu ($formattedAvg). Terbesar di kategori $topCatName ($formattedTopCat).',
      );
    }

    // 5. Aturan C (Pengguna baru tanpa riwayat 3 hari): >= 30% pemasukan bulan ini dalam sehari
    if (baselineDailyAverage == 0 && todayExpense >= minNewUserDailyExpense) {
      final incomeThisMonth = transactions
          .where((t) =>
              t.isIncome &&
              t.transactionDate.month == refDate.month &&
              t.transactionDate.year == refDate.year)
          .fold<int>(0, (sum, t) => sum + t.nominal);

      if (incomeThisMonth > 0 &&
          todayExpense >= (incomeThisMonth * 0.30).round()) {
        final ratio = todayExpense / incomeThisMonth;
        final percent = (ratio * 100).round();
        final severity = percent >= 50
            ? AnomalySeverity.critical
            : AnomalySeverity.warning;

        return SpendingAnomalyResult(
          isAnomaly: true,
          severity: severity,
          reason: 'monthly_income_ratio',
          todayExpense: todayExpense,
          baselineDailyAverage: baselineDailyAverage,
          dailyLimit: dailyLimit,
          ratio: ratio,
          topCategoryToday: topCatName,
          topCategoryAmountToday: topCatAmount,
          title: 'Pengeluaran Hari Ini Terlalu Besar',
          message:
              'Pengeluaran hari ini ($formattedToday) sudah menghabiskan $percent% dari pemasukan bulan ini. Terbesar di kategori $topCatName ($formattedTopCat).',
        );
      }
    }

    return SpendingAnomalyResult.none(
      todayExpense: todayExpense,
      baselineDailyAverage: baselineDailyAverage,
      dailyLimit: dailyLimit,
    );
  }
}
