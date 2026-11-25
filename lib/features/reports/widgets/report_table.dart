import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_card.dart';

/// Tabel rincian transaksi laporan keuangan
class ReportTable extends StatelessWidget {
  final List<TransactionModel> transactions;
  final int totalIncome;
  final int totalExpense;
  final int netBalance;

  const ReportTable({
    super.key,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final surfaceCol = NeoColors.surface(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    return NeoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Kartu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NeoColors.headerBg(context),
              border: Border(
                bottom: BorderSide(color: borderCol, width: 3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'DETAIL TRANSAKSI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaceCol,
                    border: Border.all(color: borderCol, width: 2),
                    boxShadow: NeoColors.hardShadow(offset: 2),
                  ),
                  child: Text(
                    '${transactions.length} TRANSAKSI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textCol,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 40, color: mutedCol),
                  const SizedBox(height: 8),
                  Text(
                    'TIDAK ADA TRANSAKSI UNTUK FILTER TERSEBUT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: mutedCol,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 40,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(surfaceCol),
                  border: TableBorder(
                    horizontalInside: BorderSide(color: borderCol, width: 1.5),
                    bottom: BorderSide(color: borderCol, width: 2),
                  ),
                  columnSpacing: 14,
                  horizontalMargin: 12,
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: textCol,
                  ),
                  dataTextStyle: TextStyle(
                    color: textCol,
                  ),
                  columns: const [
                    DataColumn(label: Text('NO')),
                    DataColumn(label: Text('TANGGAL')),
                    DataColumn(label: Text('KATEGORI')),
                    DataColumn(label: Text('DESKRIPSI')),
                    DataColumn(label: Text('PEMASUKAN (RP)'), numeric: true),
                    DataColumn(label: Text('PENGELUARAN (RP)'), numeric: true),
                  ],
                  rows: [
                    ...transactions.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final tx = entry.value;
                      final isInc = tx.isIncome;

                      return DataRow(
                        cells: [
                          DataCell(Text(idx.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataCell(Text(DateFormatter.formatDate(tx.transactionDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: secondaryCol,
                                border: Border.all(color: borderCol, width: 1.5),
                              ),
                              child: Text(
                                tx.categoryName.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textCol),
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                tx.description.isNotEmpty ? tx.description : '-',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              isInc ? CurrencyFormatter.formatRupiah(tx.nominal) : '-',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: isInc ? NeoColors.incomeText(context) : textCol,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              !isInc ? CurrencyFormatter.formatRupiah(tx.nominal) : '-',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: !isInc ? NeoColors.expenseText(context) : textCol,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    // Baris TOTAL
                    DataRow(
                      color: WidgetStateProperty.all(secondaryCol),
                      cells: [
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(
                          Text(
                            'TOTAL',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: textCol),
                          ),
                        ),
                        DataCell(
                          Text(
                            CurrencyFormatter.formatRupiah(totalIncome),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: NeoColors.incomeText(context),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            CurrencyFormatter.formatRupiah(totalExpense),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: NeoColors.expenseText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Baris SALDO BERSIH
                    DataRow(
                      color: WidgetStateProperty.all(NeoColors.yellowAccent),
                      cells: [
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(
                          Text(
                            'SALDO BERSIH',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: NeoColors.textDark,
                            ),
                          ),
                        ),
                        const DataCell(Text('')),
                        DataCell(
                          Text(
                            CurrencyFormatter.formatRupiah(netBalance),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: NeoColors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

