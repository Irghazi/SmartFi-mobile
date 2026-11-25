import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/neo_card.dart';

/// 3 Kartu Ringkasan Keuangan Laporan (Pemasukan, Pengeluaran, Saldo Akhir)
class ReportSummaryCards extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int netBalance;

  const ReportSummaryCards({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
  });

  Widget _buildSummaryTile({
    required Color backgroundColor,
    required String title,
    required int amount,
    required IconData icon,
  }) {
    return NeoCard(
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: NeoColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatRupiah(amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: NeoColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NeoColors.white,
              border: Border.all(color: NeoColors.black, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Icon(icon, color: NeoColors.black, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSummaryTile(
          backgroundColor: NeoColors.successGreenLight,
          title: 'TOTAL PEMASUKAN',
          amount: totalIncome,
          icon: Icons.arrow_downward,
        ),
        const SizedBox(height: 10),
        _buildSummaryTile(
          backgroundColor: NeoColors.dangerRedLight,
          title: 'TOTAL PENGELUARAN',
          amount: totalExpense,
          icon: Icons.arrow_upward,
        ),
        const SizedBox(height: 10),
        _buildSummaryTile(
          backgroundColor: NeoColors.primaryBlueLight,
          title: 'SALDO AKHIR',
          amount: netBalance,
          icon: Icons.account_balance_wallet,
        ),
      ],
    );
  }
}

