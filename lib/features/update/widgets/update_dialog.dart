import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_button.dart';
import '../providers/app_update_provider.dart';

/// Modal Neobrutalism untuk menampilkan detail pembaruan, progress unduhan APK,
/// panduan izin instalasi Android, dan pemicu installer.
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    AudioService().playClickSound();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99000000),
      builder: (_) => const UpdateDialog(),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final info = updateState.updateInfo;

    final isForce = updateState.isForceRequired;
    final isDownloading = updateState.status == AppUpdateStatus.downloading;
    final isNeedsPermission =
        updateState.status == AppUpdateStatus.needsPermission;
    final isReadyToInstall =
        updateState.status == AppUpdateStatus.readyToInstall;
    final hasError = updateState.status == AppUpdateStatus.error &&
        updateState.errorMessage != null;
    final canDismiss = !isForce && !isDownloading;

    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    final progress = updateState.downloadProgress;
    final progressPercent = progress != null ? (progress * 100).round() : null;

    return PopScope(
      canPop: canDismiss,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !isForce) {
          notifier.dismissOptionalUpdate();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
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
                // Header Neobrutalism
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isForce
                              ? 'PEMBARUAN WAJIB'
                              : 'PEMBARUAN TERSEDIA',
                          style: TextStyle(
                            color: textCol,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      NeoBadge(
                        text: isForce ? 'WAJIB' : 'BARU',
                        backgroundColor: isForce
                            ? NeoColors.dangerRedLight
                            : NeoColors.yellowAccent,
                        fontSize: 10,
                      ),
                      if (canDismiss) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            AudioService().playClickSound();
                            notifier.dismissOptionalUpdate();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: NeoColors.dangerRedLight,
                              border: Border.all(
                                color: NeoColors.black,
                                width: 2,
                              ),
                              boxShadow: NeoColors.hardShadow(offset: 2),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: NeoColors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Konten Modal
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ringkasan Versi
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: secondaryCol,
                            border: Border.all(color: borderCol, width: 2),
                            boxShadow: NeoColors.hardShadow(offset: 2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: NeoColors.primaryBlue,
                                  border: Border.all(
                                    color: NeoColors.black,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.system_update,
                                  color: NeoColors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SMARTFI MOBILE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      info != null
                                          ? 'v${updateState.currentVersion.versionName} → v${info.latestVersion}'
                                          : updateState.currentVersion.displayLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: NeoColors.blueAccentText(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Catatan Rilis
                        if (info != null && info.releaseNotes.isNotEmpty) ...[
                          Text(
                            'APA YANG BARU',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                              color: mutedCol,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 140),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: secondaryCol,
                              border: Border.all(color: borderCol, width: 2),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                info.releaseNotes,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.45,
                                  color: textCol,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Progress Unduhan APK
                        if (isDownloading) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: secondaryCol,
                              border: Border.all(color: borderCol, width: 2),
                              boxShadow: NeoColors.hardShadow(offset: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'MENGUNDUH PEMBARUAN...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      progressPercent != null
                                          ? '$progressPercent%'
                                          : _formatBytes(
                                              updateState.receivedBytes,
                                            ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: NeoColors.blueAccentText(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: NeoColors.surface(context),
                                    border: Border.all(
                                      color: borderCol,
                                      width: 2,
                                    ),
                                  ),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.transparent,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      NeoColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  updateState.totalBytes > 0
                                      ? '${_formatBytes(updateState.receivedBytes)} / ${_formatBytes(updateState.totalBytes)}'
                                      : 'Terunduh: ${_formatBytes(updateState.receivedBytes)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: mutedCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          NeoButton(
                            text: 'Batalkan Unduhan',
                            variant: NeoButtonVariant.outline,
                            onPressed: notifier.cancelDownload,
                          ),
                        ] else if (isNeedsPermission) ...[
                          // Panduan Izin Instalasi APK Android 8+
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NeoColors.yellowAccent,
                              border: Border.all(
                                color: NeoColors.black,
                                width: 2,
                              ),
                              boxShadow: NeoColors.hardShadow(offset: 2),
                            ),
                            child: const Text(
                              'File APK sudah siap! Aktifkan izin "Izinkan dari sumber ini" untuk SmartFi di Pengaturan Android, lalu kembali dan tekan Lanjutkan Instal.',
                              style: TextStyle(
                                color: NeoColors.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          NeoButton(
                            text: 'Buka Pengaturan Izin',
                            variant: NeoButtonVariant.warning,
                            icon: const Icon(
                              Icons.security,
                              size: 18,
                              color: NeoColors.black,
                            ),
                            onPressed: notifier.openInstallPermissionSettings,
                          ),
                          const SizedBox(height: 10),
                          NeoButton(
                            text: 'Lanjutkan Instal',
                            variant: NeoButtonVariant.success,
                            icon: const Icon(
                              Icons.install_mobile,
                              size: 18,
                              color: NeoColors.black,
                            ),
                            onPressed: notifier.retryInstall,
                          ),
                        ] else if (isReadyToInstall) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NeoColors.successGreenLight,
                              border: Border.all(
                                color: NeoColors.black,
                                width: 2,
                              ),
                              boxShadow: NeoColors.hardShadow(offset: 2),
                            ),
                            child: const Text(
                              'Pembaruan selesai diunduh. Tekan tombol di bawah jika jendela installer Android belum muncul.',
                              style: TextStyle(
                                color: NeoColors.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          NeoButton(
                            text: 'Instal Pembaruan',
                            variant: NeoButtonVariant.success,
                            icon: const Icon(
                              Icons.install_mobile,
                              size: 18,
                              color: NeoColors.black,
                            ),
                            onPressed: notifier.retryInstall,
                          ),
                        ] else ...[
                          // Error Banner (jika unduhan/instalasi gagal)
                          if (hasError) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: NeoColors.dangerRed,
                                border: Border.all(
                                  color: NeoColors.black,
                                  width: 2,
                                ),
                                boxShadow: NeoColors.hardShadow(offset: 2),
                              ),
                              child: Text(
                                updateState.errorMessage!,
                                style: const TextStyle(
                                  color: NeoColors.textLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          NeoButton(
                            text: hasError ? 'Coba Lagi' : 'Update Sekarang',
                            variant: NeoButtonVariant.primary,
                            icon: const Icon(
                              Icons.download,
                              size: 18,
                              color: NeoColors.white,
                            ),
                            onPressed: notifier.startDownloadAndInstall,
                          ),
                          if (!isForce) ...[
                            const SizedBox(height: 10),
                            NeoButton(
                              text: 'Nanti Saja',
                              variant: NeoButtonVariant.outline,
                              onPressed: () {
                                notifier.dismissOptionalUpdate();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ],
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
