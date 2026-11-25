import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transaction_provider.dart';

/// Kartu koreksi saldo aktual manual
class BalanceCorrectionCard extends ConsumerStatefulWidget {
  const BalanceCorrectionCard({super.key});

  @override
  ConsumerState<BalanceCorrectionCard> createState() => _BalanceCorrectionCardState();
}

class _BalanceCorrectionCardState extends ConsumerState<BalanceCorrectionCard> {
  final TextEditingController _balanceController = TextEditingController();
  int _rawInput = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  void _onBalanceChanged(String val) {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      _rawInput = 0;
      _balanceController.value = const TextEditingValue(text: '');
      setState(() {});
      return;
    }
    final parsed = int.tryParse(clean) ?? 0;
    _rawInput = parsed;
    final formatted = CurrencyFormatter.formatRupiah(parsed);
    _balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  Future<void> _handleCorrectBalance(int currentBalance) async {
    final diff = _rawInput - currentBalance;
    if (diff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo sudah sesuai dengan data saat ini.'),
          backgroundColor: NeoColors.warningYellow,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final isInc = diff > 0;
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.id;
      if (userId == null) {
        throw Exception('Sesi login tidak ditemukan.');
      }

      final tx = TransactionModel(
        id: 'tx_adj_${now.millisecondsSinceEpoch}',
        userId: userId,
        type: isInc ? 'income' : 'expense',
        nominal: diff.abs(),
        categoryName: 'Penyesuaian Saldo',
        description: 'Koreksi saldo manual via Pengaturan',
        transactionDate: now,
        createdAt: now,
      );

      await ref.read(transactionsProvider.notifier).addTransaction(tx);
      _balanceController.clear();
      _rawInput = 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo berhasil dikoreksi!'),
            backgroundColor: NeoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengoreksi saldo: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final txs = transactionsAsync.asData?.value ?? [];

    final inc = txs.where((t) => t.isIncome).fold<int>(0, (sum, t) => sum + t.nominal);
    final exp = txs.where((t) => t.isExpense).fold<int>(0, (sum, t) => sum + t.nominal);
    final currentBalance = inc - exp;

    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeoColors.headerBg(context),
                  border: Border.all(color: borderCol, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(Icons.account_balance_wallet, color: textCol, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KOREKSI SALDO AKTUAL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'SESUAIKAN DENGAN SALDO REKENING RIIL',
                      style: TextStyle(
                        fontSize: 9,
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

          // Tampilan Saldo Tersimpan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: secondaryCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'SALDO TERSIMPAN SAAT INI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    CurrencyFormatter.formatRupiah(currentBalance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: NeoColors.blueAccentText(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          NeoInput(
            label: 'SALDO RIIL BARU (RP)',
            controller: _balanceController,
            hintText: 'Masukkan saldo sebenarnya',
            keyboardType: TextInputType.number,
            onChanged: _onBalanceChanged,
          ),
          const SizedBox(height: 16),

          NeoButton(
            text: _isLoading ? 'MENYESUAIKAN...' : 'KOREKSI SALDO',
            backgroundColor: NeoColors.primaryBlue,
            textColor: NeoColors.white,
            onPressed: _isLoading || _balanceController.text.isEmpty
                ? null
                : () => _handleCorrectBalance(currentBalance),
          ),
        ],
      ),
    );
  }
}

