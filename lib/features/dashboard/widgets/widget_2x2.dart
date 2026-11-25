import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_card.dart';

class Widget2x2 extends StatelessWidget {
  final int balance;
  final int incomeThisMonth;
  final int expenseThisMonth;
  final int targetSavings;
  final List<TransactionModel> transactionsThisMonth;

  const Widget2x2({
    super.key,
    required this.balance,
    required this.incomeThisMonth,
    required this.expenseThisMonth,
    required this.targetSavings,
    required this.transactionsThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Progress Tabungan terhadap Target
    final target = targetSavings > 0 ? targetSavings : 5000000;
    double savingsProgress = balance > 0 ? (balance / target) : 0.0;
    if (savingsProgress > 1.0) savingsProgress = 1.0;
    final savingsPercent = (savingsProgress * 100).toInt();

    // 2. Rasio Pemasukan & Pengeluaran Bulan Ini
    final totalFlow = incomeThisMonth + expenseThisMonth;
    final incomeProgress = totalFlow > 0 ? (incomeThisMonth / totalFlow) : 0.0;

    final double expenseProgress;
    final String expenseSubtext;
    if (incomeThisMonth > 0) {
      expenseProgress = (expenseThisMonth / incomeThisMonth).clamp(0.0, 1.0);
      expenseSubtext = '${(expenseProgress * 100).toInt()}% dari pemasukan';
    } else if (expenseThisMonth > 0) {
      expenseProgress = 1.0;
      expenseSubtext = 'Belum ada pemasukan';
    } else {
      expenseProgress = 0.0;
      expenseSubtext = 'Belum ada pengeluaran';
    }

    // 3. Kategori Pengeluaran Terbesar
    final catTotals = <String, int>{};
    for (final t in transactionsThisMonth.where((t) => t.isExpense)) {
      catTotals[t.categoryName] = (catTotals[t.categoryName] ?? 0) + t.nominal;
    }
    String topCatName = 'Belum Ada';
    int topCatAmount = 0;
    catTotals.forEach((cat, amt) {
      if (amt > topCatAmount) {
        topCatAmount = amt;
        topCatName = cat;
      }
    });
    final topCatPercent = expenseThisMonth > 0 ? ((topCatAmount / expenseThisMonth) * 100).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATISTIK 2X2 (BULAN INI)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: NeoColors.text(context),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildDoughnutTile(
                  context: context,
                  title: 'SALDO',
                  valueText: CurrencyFormatter.formatRupiah(balance),
                  subtext: '$savingsPercent% dari target',
                  color: NeoColors.primaryBlue,
                  progress: savingsProgress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDoughnutTile(
                  context: context,
                  title: 'PEMASUKAN',
                  valueText: CurrencyFormatter.formatRupiah(incomeThisMonth),
                  subtext: 'Bulan ini',
                  color: NeoColors.successGreen,
                  progress: incomeProgress,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildDoughnutTile(
                  context: context,
                  title: 'PENGELUARAN',
                  valueText: CurrencyFormatter.formatRupiah(expenseThisMonth),
                  subtext: expenseSubtext,
                  color: incomeThisMonth > 0 &&
                          expenseThisMonth >= (incomeThisMonth * 0.8)
                      ? NeoColors.warningYellow
                      : NeoColors.dangerRed,
                  progress: expenseProgress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDoughnutTile(
                  context: context,
                  title: 'TERBANYAK',
                  valueText: topCatName,
                  subtext: '$topCatPercent% pengeluaran',
                  color: NeoColors.purpleAccent,
                  progress: topCatPercent / 100.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoughnutTile({
    required BuildContext context,
    required String title,
    required String valueText,
    required String subtext,
    required Color color,
    required double progress,
  }) {
    final validProgress = progress.clamp(0.0, 1.0);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return NeoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: mutedCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 24,
                    sections: [
                      if (validProgress > 0)
                        PieChartSectionData(
                          value: validProgress,
                          color: color,
                          radius: 10,
                          showTitle: false,
                          borderSide: BorderSide(color: borderCol, width: 1.5),
                        ),
                      if (1.0 - validProgress > 0)
                        PieChartSectionData(
                          value: 1.0 - validProgress,
                          color: NeoColors.surfaceSecondary(context),
                          radius: 10,
                          showTitle: false,
                          borderSide: BorderSide(color: borderCol, width: 1.5),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: NeoColors.surface(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${(validProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: textCol,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: mutedCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

