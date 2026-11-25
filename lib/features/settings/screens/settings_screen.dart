import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/app_update_card.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/balance_correction_card.dart';
import '../widgets/danger_zone_card.dart';
import '../widgets/notification_settings_card.dart';
import '../widgets/profile_settings_card.dart';
import '../widgets/savings_target_card.dart';
import '../widgets/subscription_info_card.dart';
import '../widgets/theme_settings_card.dart';

/// Layar Pengaturan & Preferensi SmartFi
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    AudioService().playClickSound();

    final confirm = await NeoModal.show<bool>(
      context: context,
      title: 'Konfirmasi Keluar',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Apakah Anda yakin ingin keluar dari akun SmartFi ini?',
            style: TextStyle(
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
                  text: 'Keluar',
                  variant: NeoButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return BlueprintBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Pengaturan
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
                child: Icon(Icons.settings, size: 24, color: textCol),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGATURAN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'KELOLA PROFIL, TARGET, DAN PREFERENSI',
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

          // 1. Profil Pengguna
          const ProfileSettingsCard(),
          const SizedBox(height: 16),

          // 2. Target Tabungan Bulanan
          const SavingsTargetCard(),
          const SizedBox(height: 16),

          // 3. Tema Tampilan (Light / Dark)
          const ThemeSettingsCard(),
          const SizedBox(height: 16),

          // 4. Efek Suara
          const AudioSettingsCard(),
          const SizedBox(height: 16),

          // 5. Pengingat Harian
          const NotificationSettingsCard(),
          const SizedBox(height: 16),

          // 6. Koreksi Saldo
          const BalanceCorrectionCard(),
          const SizedBox(height: 16),

          // 7. Status Langganan
          const SubscriptionInfoCard(),
          const SizedBox(height: 16),

          // 8. Pembaruan Aplikasi (Auto-Update Firebase)
          const AppUpdateCard(),
          const SizedBox(height: 16),

          // 9. Zona Bahaya
          const DangerZoneCard(),
          const SizedBox(height: 24),

          // Tombol Navigasi Kelola Kategori
          NeoButton(
            text: 'KELOLA KATEGORI TRANSAKSI',
            variant: NeoButtonVariant.outline,
            icon: Icon(Icons.category, size: 18, color: textCol),
            onPressed: () {
              context.push('/categories');
            },
          ),
          const SizedBox(height: 12),

          // Tombol Logout
          NeoButton(
            text: 'KELUAR DARI AKUN',
            icon: const Icon(Icons.logout, size: 18, color: NeoColors.white),
            backgroundColor: NeoColors.dangerRed,
            textColor: NeoColors.white,
            onPressed: () => _handleLogout(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
