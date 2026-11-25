import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neo_colors.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../data/services/pdf_export_service.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../widgets/report_filter_card.dart';
import '../widgets/report_summary_cards.dart';
import '../widgets/report_table.dart';

/// Layar Laporan Keuangan SmartFi
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _reportType = 'all';

  // Filter yang sedang aktif diterapkan
  DateTime? _appliedStartDate;
  DateTime? _appliedEndDate;
  String _appliedReportType = 'all';

  bool _isExporting = false;

  void _applyFilter() {
    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal mulai tidak boleh melebihi tanggal akhir.'),
          backgroundColor: NeoColors.warningYellow,
        ),
      );
      return;
    }
    setState(() {
      _appliedStartDate = _startDate;
      _appliedEndDate = _endDate;
      _appliedReportType = _reportType;
    });
  }

  void _resetFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _reportType = 'all';
      _appliedStartDate = null;
      _appliedEndDate = null;
      _appliedReportType = 'all';
    });
  }

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    return all.where((t) {
      if (_appliedReportType != 'all' && t.type != _appliedReportType) {
        return false;
      }
      if (_appliedStartDate != null) {
        final start = DateTime(
          _appliedStartDate!.year,
          _appliedStartDate!.month,
          _appliedStartDate!.day,
        );
        if (t.transactionDate.isBefore(start)) return false;
      }
      if (_appliedEndDate != null) {
        final end = DateTime(
          _appliedEndDate!.year,
          _appliedEndDate!.month,
          _appliedEndDate!.day,
          23,
          59,
          59,
          999,
          999,
        );
        if (t.transactionDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleExportPdf(
    List<TransactionModel> transactions,
    int totalIncome,
    int totalExpense,
    int netBalance,
  ) async {
    setState(() => _isExporting = true);
    try {
      await PdfExportService.exportPdf(
        transactions: transactions,
        startDate: _appliedStartDate,
        endDate: _appliedEndDate,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netBalance: netBalance,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor PDF: $e'),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportCsv(
    List<TransactionModel> transactions,
    int totalIncome,
    int totalExpense,
    int netBalance,
  ) async {
    setState(() => _isExporting = true);
    try {
      await CsvExportService.exportCsv(
        transactions: transactions,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netBalance: netBalance,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor Excel/CSV: $e'),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return BlueprintBackground(
      child: RefreshIndicator(
        color: NeoColors.primaryBlue,
        backgroundColor: NeoColors.surface(context),
        onRefresh: () async {
          await ref.read(transactionsProvider.notifier).loadTransactions(showLoading: false);
        },
        child: transactionsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Center(
                  child: CircularProgressIndicator(color: textCol),
                ),
              ),
            ],
          ),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Icon(Icons.cloud_off, size: 48, color: mutedCol),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat data laporan.\n($err)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: textCol),
              ),
              const SizedBox(height: 16),
              NeoButton(
                text: 'Coba Lagi',
                isFullWidth: false,
                onPressed: () => ref.read(transactionsProvider.notifier).loadTransactions(),
              ),
            ],
          ),
          data: (allTransactions) {
            final filteredTxs = _getFilteredTransactions(allTransactions);

            final totalIncome = filteredTxs
                .where((t) => t.isIncome)
                .fold<int>(0, (sum, t) => sum + t.nominal);
            final totalExpense = filteredTxs
                .where((t) => t.isExpense)
                .fold<int>(0, (sum, t) => sum + t.nominal);
            final netBalance = totalIncome - totalExpense;

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header Laporan
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: NeoColors.surface(context),
                        border: Border.all(color: borderCol, width: 2),
                        boxShadow: NeoColors.hardShadow(offset: 3),
                      ),
                      child: Icon(
                        Icons.description,
                        size: 24,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAPORAN KEUANGAN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: textCol,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FILTER DAN EKSPOR DATA KEUANGANMU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mutedCol,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Kartu Filter
                ReportFilterCard(
                  startDate: _startDate,
                  endDate: _endDate,
                  reportType: _reportType,
                  onStartDateChanged: (d) => setState(() => _startDate = d),
                  onEndDateChanged: (d) => setState(() => _endDate = d),
                  onReportTypeChanged: (t) => setState(() => _reportType = t),
                  onSearch: _applyFilter,
                  onReset: _resetFilter,
                ),
                const SizedBox(height: 16),

                // Ringkasan Keuangan (3 Kartu)
                ReportSummaryCards(
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netBalance: netBalance,
                ),
                const SizedBox(height: 16),

                // Tabel Transaksi
                ReportTable(
                  transactions: filteredTxs,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netBalance: netBalance,
                ),
                const SizedBox(height: 20),

                // Tombol Ekspor PDF & Excel
                Row(
                  children: [
                    Expanded(
                      child: NeoButton(
                        text: _isExporting ? 'MEMPROSES...' : 'EKSPOR PDF',
                        variant: NeoButtonVariant.outline,
                        icon: Icon(
                          Icons.picture_as_pdf,
                          size: 18,
                          color: NeoColors.text(context),
                        ),
                        onPressed: filteredTxs.isEmpty || _isExporting
                            ? null
                            : () => _handleExportPdf(
                                filteredTxs,
                                totalIncome,
                                totalExpense,
                                netBalance,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeoButton(
                        text: _isExporting ? 'MEMPROSES...' : 'EKSPOR EXCEL',
                        icon: const Icon(
                          Icons.table_chart,
                          size: 18,
                          color: NeoColors.black,
                        ),
                        backgroundColor: NeoColors.yellowAccent,
                        textColor: NeoColors.black,
                        onPressed: filteredTxs.isEmpty || _isExporting
                            ? null
                            : () => _handleExportCsv(
                                filteredTxs,
                                totalIncome,
                                totalExpense,
                                netBalance,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
