import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../update/providers/app_update_provider.dart';
import '../../update/widgets/update_dialog.dart';

/// Kartu pemeriksaan & pembaruan aplikasi otomatis dari Cloud Firestore di layar Pengaturan
class AppUpdateCard extends ConsumerWidget {
  const AppUpdateCard({super.key});

  Future<void> _handleAction(BuildContext context, WidgetRef ref) async {
    final state = ref.read(appUpdateProvider);
    if (state.hasUpdate) {
      await UpdateDialog.show(context);
      return;
    }

    final status =
        await ref.read(appUpdateProvider.notifier).checkForUpdate(manual: true);
    if (!context.mounted) return;

    if (status == AppUpdateStatus.available ||
        status == AppUpdateStatus.readyToInstall) {
      await UpdateDialog.show(context);
    } else if (status == AppUpdateStatus.error) {
      final err = ref.read(appUpdateProvider).errorMessage ??
          'Gagal memeriksa pembaruan.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: NeoColors.dangerRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplikasi SmartFi Anda sudah menggunakan versi terbaru!'),
          backgroundColor: NeoColors.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState.status == AppUpdateStatus.checking;
    final hasUpdate = updateState.hasUpdate;

    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    final badgeText = isChecking
        ? 'MENGECEK'
        : (hasUpdate
            ? 'v${updateState.updateInfo!.latestVersion}'
            : 'TERBARU');
    final badgeColor = isChecking
        ? NeoColors.primaryBlueLight
        : (hasUpdate ? NeoColors.yellowAccent : NeoColors.successGreenLight);

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
                  color: hasUpdate
                      ? NeoColors.yellowAccent
                      : NeoColors.headerBg(context),
                  border: Border.all(
                    color: hasUpdate ? NeoColors.black : borderCol,
                    width: 2,
                  ),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(
                  Icons.system_update,
                  color: hasUpdate ? NeoColors.black : textCol,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PEMBARUAN APLIKASI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'SINKRONISASI VERSI OTOMATIS FIREBASE',
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: secondaryCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERSI TERPASANG: ${updateState.currentVersion.displayLabel.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasUpdate
                            ? 'Versi baru tersedia untuk diunduh dan dipasang'
                            : 'Cek berkala otomatis saat aplikasi dibuka',
                        style: TextStyle(fontSize: 10, color: mutedCol),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                NeoBadge(
                  text: badgeText,
                  backgroundColor: badgeColor,
                  fontSize: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NeoButton(
            text: hasUpdate ? 'Update Sekarang' : 'Cek Pembaruan',
            isLoading: isChecking,
            variant:
                hasUpdate ? NeoButtonVariant.warning : NeoButtonVariant.primary,
            icon: Icon(
              hasUpdate ? Icons.download : Icons.refresh,
              size: 18,
              color: hasUpdate ? NeoColors.black : NeoColors.white,
            ),
            onPressed: isChecking ? null : () => _handleAction(context, ref),
          ),
        ],
      ),
    );
  }
}
