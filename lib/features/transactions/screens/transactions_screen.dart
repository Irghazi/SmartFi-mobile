import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../../../shared/widgets/neo_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/smart_input_box.dart';
import '../widgets/transaction_form_dialog.dart';
import '../widgets/transaction_monthly_summary.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _selectedTypeFilter = 'all'; // 'all' | 'income' | 'expense'
  String _selectedDateMode = 'all'; // 'all' | 'this_month' | 'custom'
  DateTimeRange? _customDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    AudioService().playClickSound();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateMode = 'custom';
      });
    }
  }

  void _confirmDelete(BuildContext context, String txId) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    NeoModal.show(
      context: context,
      title: 'Hapus Transaksi',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Apakah Anda yakin ingin menghapus transaksi ini? Tindakan ini tidak dapat dibatalkan.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'Batal',
                  variant: NeoButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: 'Hapus',
                  variant: NeoButtonVariant.danger,
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await ref.read(transactionsProvider.notifier).deleteTransaction(txId);
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Transaksi berhasil dihapus')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Gagal menghapus transaksi: ${e.toString().replaceFirst('Exception: ', '')}'),
                          backgroundColor: NeoColors.dangerRed,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final userId = userAsync.asData?.value?.id;

    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.asData?.value ?? CategoryModel.defaultCategories;

    final txsAsync = ref.watch(transactionsProvider);
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
        child: txsAsync.when(
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
                'Terjadi kesalahan saat memuat transaksi.\n($err)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: textCol),
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
            final now = DateTime.now();
            final searchQuery = _searchController.text.toLowerCase().trim();
            final filteredTxs = allTransactions.where((tx) {
              if (_selectedTypeFilter != 'all' && tx.type != _selectedTypeFilter) {
                return false;
              }
              if (_selectedDateMode == 'this_month') {
                if (tx.transactionDate.month != now.month ||
                    tx.transactionDate.year != now.year) {
                  return false;
                }
              } else if (_selectedDateMode == 'custom' && _customDateRange != null) {
                final start = DateTime(
                  _customDateRange!.start.year,
                  _customDateRange!.start.month,
                  _customDateRange!.start.day,
                );
                final end = DateTime(
                  _customDateRange!.end.year,
                  _customDateRange!.end.month,
                  _customDateRange!.end.day,
                  23,
                  59,
                  59,
                  999,
                );
                if (tx.transactionDate.isBefore(start) || tx.transactionDate.isAfter(end)) {
                  return false;
                }
              }
              if (searchQuery.isNotEmpty) {
                final inDesc = tx.description.toLowerCase().contains(searchQuery);
                final inCat = tx.categoryName.toLowerCase().contains(searchQuery);
                return inDesc || inCat;
              }
              return true;
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header Title
                NeoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: NeoColors.yellowAccent,
                          border: Border.all(color: NeoColors.black, width: 2),
                          boxShadow: NeoColors.hardShadow(offset: 2),
                        ),
                        child: const Icon(Icons.swap_horiz, size: 28, color: NeoColors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KELOLA TRANSAKSI',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Lacak dan catat keuangan Anda dengan bantuan AI.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: mutedCol,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Smart Input Box
                SmartInputBox(
                  categories: categories,
                  onSaveTransaction: ({
                    required String type,
                    required String category,
                    required int nominal,
                    required String description,
                    required DateTime transactionDate,
                  }) async {
                    if (userId == null) {
                      throw Exception('Sesi login tidak ditemukan.');
                    }
                    final catList = (categories.isNotEmpty
                            ? categories
                            : CategoryModel.defaultCategories)
                        .where((c) => c.type == type)
                        .toList();
                    final matches = catList.where((c) => c.name == category);
                    final catMatch = matches.isNotEmpty
                        ? matches.first
                        : (catList.isNotEmpty ? catList.first : null);

                    final newTx = TransactionModel(
                      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                      userId: userId,
                      type: type,
                      nominal: nominal,
                      description: description,
                      categoryId: catMatch?.id,
                      categoryName: catMatch?.name ?? category,
                      transactionDate: transactionDate,
                      createdAt: DateTime.now(),
                    );

                    await ref.read(transactionsProvider.notifier).addTransaction(newTx);
                  },
                ),
                const SizedBox(height: 16),

                // 2. Ringkasan Bulan Ini
                TransactionMonthlySummary(transactions: allTransactions),
                const SizedBox(height: 16),

                // 3. Riwayat Transaksi Container
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'RIWAYAT TRANSAKSI',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          NeoButton(
                            text: 'Tambah',
                            isFullWidth: false,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            variant: NeoButtonVariant.warning,
                            icon: const Icon(Icons.add, size: 16, color: NeoColors.black),
                            onPressed: userId == null
                                ? null
                                : () {
                                    TransactionFormDialog.show(
                                      context: context,
                                      userId: userId,
                                      categories: categories,
                                      onSave: (tx) async {
                                        await ref.read(transactionsProvider.notifier).addTransaction(tx);
                                      },
                                    );
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pencarian & Filter Bar
                      NeoInput(
                        hintText: 'Cari transaksi...',
                        controller: _searchController,
                        prefixIcon: Icon(Icons.search, color: mutedCol),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close, size: 18, color: mutedCol),
                                onPressed: () {
                                  AudioService().playClickSound();
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Filter Tipe (Semua, Pemasukan, Pengeluaran)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Semua', 'all', _selectedTypeFilter, (v) => _selectedTypeFilter = v),
                            const SizedBox(width: 8),
                            _buildFilterChip('Pemasukan', 'income', _selectedTypeFilter, (v) => _selectedTypeFilter = v),
                            const SizedBox(width: 8),
                            _buildFilterChip('Pengeluaran', 'expense', _selectedTypeFilter, (v) => _selectedTypeFilter = v),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filter Rentang Tanggal
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Semua Waktu', 'all', _selectedDateMode, (v) {
                              _selectedDateMode = v;
                              _customDateRange = null;
                            }),
                            const SizedBox(width: 8),
                            _buildFilterChip('Bulan Ini', 'this_month', _selectedDateMode, (v) {
                              _selectedDateMode = v;
                              _customDateRange = null;
                            }),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _pickDateRange,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedDateMode == 'custom'
                                      ? NeoColors.yellowAccent
                                      : NeoColors.surface(context),
                                  border: Border.all(
                                    color: _selectedDateMode == 'custom' ? NeoColors.black : borderCol,
                                    width: 2,
                                  ),
                                  boxShadow: _selectedDateMode == 'custom' ? NeoColors.hardShadow(offset: 2) : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 13,
                                      color: _selectedDateMode == 'custom' ? NeoColors.black : textCol,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _selectedDateMode == 'custom' && _customDateRange != null
                                          ? '${DateFormatter.formatTanggalPendek(_customDateRange!.start)} - ${DateFormatter.formatTanggalPendek(_customDateRange!.end)}'
                                          : 'PILIH TANGGAL',
                                      style: TextStyle(
                                        color: _selectedDateMode == 'custom' ? NeoColors.textDark : textCol,
                                        fontWeight: _selectedDateMode == 'custom' ? FontWeight.w900 : FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Daftar Transaksi
                      if (filteredTxs.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            'Belum ada transaksi ditemukan.',
                            style: TextStyle(fontWeight: FontWeight.w800, color: mutedCol),
                          ),
                        ),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTxs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = filteredTxs[index];
                            final isIncome = tx.isIncome;

                            return GestureDetector(
                              onTap: userId == null
                                  ? null
                                  : () {
                                      TransactionFormDialog.show(
                                        context: context,
                                        userId: userId,
                                        categories: categories,
                                        editingTx: tx,
                                        onSave: (updatedTx) async {
                                          await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
                                        },
                                      );
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: NeoColors.surfaceSecondary(context),
                                  border: Border.all(color: borderCol, width: 2),
                                  boxShadow: NeoColors.hardShadow(offset: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tx.description,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: textCol,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            AudioService().playClickSound();
                                            _confirmDelete(context, tx.id);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: NeoColors.dangerRedLight,
                                              border: Border.all(color: NeoColors.black, width: 2),
                                              boxShadow: NeoColors.hardShadow(offset: 2),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: NeoColors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
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
                                                  fontSize: 11,
                                                  color: mutedCol,
                                                ),
                                              ),
                                              NeoBadge(
                                                text: tx.categoryName,
                                                fontSize: 10,
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatRupiah(tx.nominal)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: isIncome
                                                ? NeoColors.incomeText(context)
                                                : NeoColors.expenseText(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String activeValue,
    ValueChanged<String> onUpdate,
  ) {
    final isSelected = activeValue == value;
    final textCol = NeoColors.text(context);
    final borderCol = NeoColors.border(context);

    return GestureDetector(
      onTap: () {
        AudioService().playClickSound();
        setState(() => onUpdate(value));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? NeoColors.primaryBlueLight : NeoColors.surface(context),
          border: Border.all(color: isSelected ? NeoColors.black : borderCol, width: 2),
          boxShadow: isSelected ? NeoColors.hardShadow(offset: 2) : [],
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? NeoColors.textDark : textCol,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
