import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_card.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<TransactionModel> transactions;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final recent5 = transactions.take(5).toList();
    final borderCol = NeoColors.border(context);
    final mutedCol = NeoColors.mutedText(context);

    return NeoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Neobrutalism
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NeoColors.headerBg(context),
              border: Border(bottom: BorderSide(color: borderCol, width: 4)),
            ),
            child: const Text(
              'RIWAYAT TRANSAKSI TERAKHIR',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),

          if (recent5.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Belum ada transaksi yang dicatat.',
                  style: TextStyle(fontWeight: FontWeight.w800, color: mutedCol),
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent5.length,
              separatorBuilder: (_, __) => Divider(color: borderCol, height: 2, thickness: 2),
              itemBuilder: (context, index) {
                final tx = recent5[index];
                final isIncome = tx.isIncome;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.description,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatRupiah(tx.nominal)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: isIncome
                                  ? NeoColors.incomeText(context)
                                  : NeoColors.expenseText(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  DateFormatter.formatTanggalPendek(tx.transactionDate),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: mutedCol,
                                  ),
                                ),
                                NeoBadge(
                                  text: tx.categoryName,
                                  fontSize: 9,
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const NeoBadge(
                            text: 'Selesai',
                            backgroundColor: NeoColors.successGreenLight,
                            icon: Icon(Icons.check_circle, size: 10, color: NeoColors.black),
                            fontSize: 8,
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

