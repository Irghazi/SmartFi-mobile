import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_card.dart';

class ExpenseBarChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const ExpenseBarChart({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    // Siapkan data 7 hari terakhir
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dailyExpenses = <int>[];
    for (final day in last7Days) {
      final dayExpense = transactions
          .where((t) => t.isExpense)
          .where((t) {
            final tDay = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
            return tDay.isAtSameMomentAs(day);
          })
          .fold<int>(0, (sum, t) => sum + t.nominal);
      dailyExpenses.add(dayExpense);
    }

    final highestExpense = dailyExpenses.fold<int>(0, (max, v) => v > max ? v : max);
    final maxVal = highestExpense == 0 ? 100000 : (highestExpense < 1000 ? 1000 : highestExpense);
    final chartMaxY = maxVal * 1.2;
    final yInterval = chartMaxY / 4;
    final textCol = NeoColors.text(context);
    final borderCol = NeoColors.border(context);
    final gridColor = NeoColors.isDark(context) ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB);

    String formatYAxis(double val) {
      if (val <= 0) return '0';
      if (val >= 1000000) {
        final jt = val / 1000000;
        return jt == jt.roundToDouble() ? '${jt.toInt()}jt' : '${jt.toStringAsFixed(1)}jt';
      }
      if (val >= 1000) {
        return '${(val / 1000).round()}k';
      }
      return val.toInt().toString();
    }

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TREN PENGELUARAN 7 HARI TERAKHIR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: textCol,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => NeoColors.surface(context),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayStr = DateFormatter.formatTanggalPendek(last7Days[group.x.toInt()]);
                      return BarTooltipItem(
                        '$dayStr\n${CurrencyFormatter.formatRupiah(rod.toY.toInt())}',
                        TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: yInterval,
                      getTitlesWidget: (val, meta) {
                        if (val > chartMaxY * 0.99 && val != chartMaxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          formatYAxis(val),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textCol),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        if (val % 1 != 0) return const SizedBox.shrink();
                        final idx = val.toInt();
                        if (idx >= 0 && idx < last7Days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              DateFormatter.formatTanggalPendek(last7Days[idx]),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textCol),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: borderCol, width: 2),
                    left: BorderSide(color: borderCol, width: 2),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dailyExpenses[i].toDouble(),
                        color: NeoColors.primaryBlue,
                        width: 18,
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: borderCol, width: 2),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

