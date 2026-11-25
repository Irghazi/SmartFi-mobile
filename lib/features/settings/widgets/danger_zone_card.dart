import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transaction_provider.dart';

/// Kartu Zona Bahaya: Hapus riwayat transaksi berdasarkan rentang
class DangerZoneCard extends ConsumerStatefulWidget {
  const DangerZoneCard({super.key});

  @override
  ConsumerState<DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends ConsumerState<DangerZoneCard> {
  String _deleteRange = 'all'; // 'this_month' | 'this_year' | 'all'
  bool _isDeleting = false;

  Future<void> _handleConfirmDelete() async {
    AudioService().playClickSound();

    final rangeText = _deleteRange == 'this_month'
        ? 'bulan ini'
        : (_deleteRange == 'this_year' ? 'tahun ini' : 'semua waktu');

    final confirmed = await NeoModal.show<bool>(
      context: context,
      title: 'Konfirmasi Hapus Transaksi',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Apakah Anda yakin ingin menghapus data transaksi untuk rentang $rangeText? Data akan hilang permanen.',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'Batal',
                  variant: NeoButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeoButton(
                  text: 'Ya, Hapus',
                  variant: NeoButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await ref
            .read(transactionsProvider.notifier)
            .deleteByRange(_deleteRange);
        if (_deleteRange == 'all') {
          final userId = ref.read(authStateProvider).asData?.value?.id;
          if (userId != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('smartfi_onboarding_completed_$userId', true);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riwayat transaksi berhasil dihapus!'),
              backgroundColor: NeoColors.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus transaksi: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: NeoColors.dangerRed,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    return NeoCard(
      borderColor: NeoColors.dangerRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeoColors.dangerRedLight,
                  border: Border.all(color: NeoColors.black, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: const Icon(
                  Icons.warning,
                  color: NeoColors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZONA BAHAYA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: NeoColors.expenseText(context),
                      ),
                    ),
                    Text(
                      'HAPUS DATA TRANSAKSI PERMANEN',
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

          // Pilihan Rentang
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RENTANG PENGHAPUSAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: secondaryCol,
                  border: Border.all(color: borderCol, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _deleteRange,
                    isExpanded: true,
                    dropdownColor: NeoColors.surface(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: textCol,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'this_month',
                        child: Text('TRANSAKSI BULAN INI'),
                      ),
                      DropdownMenuItem(
                        value: 'this_year',
                        child: Text('TRANSAKSI TAHUN INI'),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('SEMUA TRANSAKSI SEPANJANG WAKTU'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _deleteRange = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          NeoButton(
            text: _isDeleting ? 'MENGHAPUS...' : 'HAPUS RIWAYAT TRANSAKSI',
            icon: const Icon(
              Icons.delete_forever,
              size: 18,
              color: NeoColors.white,
            ),
            backgroundColor: NeoColors.dangerRed,
            textColor: NeoColors.white,
            onPressed: _isDeleting ? null : _handleConfirmDelete,
          ),
        ],
      ),
    );
  }
}
