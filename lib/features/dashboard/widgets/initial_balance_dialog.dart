import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_input.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transaction_provider.dart';

/// Modal onboarding untuk mengisi saldo awal (minimal Rp 100.000)
class InitialBalanceDialog extends ConsumerStatefulWidget {
  const InitialBalanceDialog({super.key});

  static Future<void> show(BuildContext context) {
    AudioService().playClickSound();
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99000000),
      builder: (_) => const InitialBalanceDialog(),
    );
  }

  @override
  ConsumerState<InitialBalanceDialog> createState() =>
      _InitialBalanceDialogState();
}

class _InitialBalanceDialogState extends ConsumerState<InitialBalanceDialog> {
  final TextEditingController _controller = TextEditingController();
  int _rawValue = 0;
  bool _isLoading = false;
  String? _errorMessage;

  void _onAmountChanged(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      _rawValue = 0;
      _controller.value = const TextEditingValue(text: '');
      setState(() => _errorMessage = null);
      return;
    }

    final parsed = int.tryParse(clean) ?? 0;
    _rawValue = parsed;
    final formatted = CurrencyFormatter.formatRupiah(parsed);

    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      if (_rawValue < 100000) {
        _errorMessage = 'Minimal pengisian saldo awal adalah Rp 100.000';
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_rawValue < 100000) {
      setState(() {
        _errorMessage = 'Masukkan saldo awal minimal Rp 100.000.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.id;
      if (userId == null) {
        throw Exception('Sesi pengguna tidak ditemukan. Silakan masuk kembali.');
      }

      final tx = TransactionModel(
        id: 'tx_init_${now.millisecondsSinceEpoch}',
        userId: userId,
        type: 'income',
        nominal: _rawValue,
        categoryName: 'Saldo Awal',
        description: 'Setup Saldo Awal',
        transactionDate: now,
        createdAt: now,
      );

      await ref.read(transactionsProvider.notifier).addTransaction(tx);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smartfi_onboarding_completed_$userId', true);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan saldo awal: ${e.toString().replaceFirst('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _rawValue >= 100000;
    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: NeoColors.surface(context),
            border: Border.all(color: borderCol, width: 4),
            boxShadow: NeoColors.hardShadow(offset: 8),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: textCol),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: NeoColors.headerBg(context),
                    border: Border(
                      bottom: BorderSide(color: borderCol, width: 4),
                    ),
                  ),
                  child: Text(
                    'SALDO AWAL',
                    style: TextStyle(
                      color: textCol,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Konten Modal (scrollable agar aman saat keyboard terbuka)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: NeoColors.black, width: 2),
                              color: NeoColors.white,
                              boxShadow: NeoColors.hardShadow(offset: 4),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const Text(
                          'SELAMAT DATANG DI SMARTFI!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mari mulai dengan mengatur saldo awal Anda agar kami bisa melacak keuangan Anda dengan akurat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedCol,
                          ),
                        ),
                        const SizedBox(height: 16),
                        NeoInput(
                          label: 'Saldo Awal (Rp)',
                          controller: _controller,
                          hintText: 'Contoh: 100.000',
                          keyboardType: TextInputType.number,
                          errorText: _errorMessage,
                          onChanged: _onAmountChanged,
                        ),
                        const SizedBox(height: 20),
                        NeoButton(
                          text: _isLoading
                              ? 'MENYIMPAN...'
                              : 'MULAI GUNAKAN SMARTFI',
                          variant: NeoButtonVariant.primary,
                          onPressed: isValid && !_isLoading ? _handleSubmit : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
