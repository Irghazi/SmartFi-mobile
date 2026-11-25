import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_update_service.dart';
import '../../../data/models/app_update_model.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  needsPermission,
  readyToInstall,
  error,
}

class AppUpdateState {
  final AppUpdateStatus status;
  final AppVersionInfo currentVersion;
  final AppUpdateInfo? updateInfo;
  final int receivedBytes;
  final int totalBytes;
  final String? downloadedApkPath;
  final String? errorMessage;
  final int? dismissedBuildNumber;

  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.currentVersion = const AppVersionInfo(versionName: '1.0.0', buildNumber: 1),
    this.updateInfo,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.downloadedApkPath,
    this.errorMessage,
    this.dismissedBuildNumber,
  });

  bool get hasUpdate =>
      updateInfo != null && updateInfo!.isUpdateAvailable(currentVersion);

  bool get isForceRequired =>
      updateInfo != null && updateInfo!.isForceRequired(currentVersion);

  double? get downloadProgress {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Menentukan apakah modal update perlu ditampilkan otomatis ke pengguna
  bool get shouldAutoPrompt {
    if (!hasUpdate || updateInfo == null) return false;
    if (isForceRequired) return true;
    return dismissedBuildNumber != updateInfo!.latestBuildNumber;
  }

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppVersionInfo? currentVersion,
    AppUpdateInfo? updateInfo,
    bool clearUpdateInfo = false,
    int? receivedBytes,
    int? totalBytes,
    String? downloadedApkPath,
    bool clearDownloadedApkPath = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? dismissedBuildNumber,
    bool clearDismissedBuildNumber = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      updateInfo: clearUpdateInfo ? null : (updateInfo ?? this.updateInfo),
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedApkPath: clearDownloadedApkPath
          ? null
          : (downloadedApkPath ?? this.downloadedApkPath),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      dismissedBuildNumber: clearDismissedBuildNumber
          ? null
          : (dismissedBuildNumber ?? this.dismissedBuildNumber),
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final AppUpdateService _service;
  StreamSubscription<AppUpdateInfo?>? _configSub;
  bool _initialized = false;

  AppUpdateNotifier(this._service, {bool autoStart = true})
      : super(const AppUpdateState()) {
    if (autoStart) {
      init();
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final current = await _service.getCurrentVersion();
    if (!mounted) return;
    state = state.copyWith(currentVersion: current);

    // Dengarkan perubahan dokumen `app_config/android` secara real-time di Firestore
    _configSub?.cancel();
    _configSub = _service.watchUpdateInfo().listen(
      (info) {
        if (!mounted) return;
        _applyRemoteInfo(info);
      },
      onError: (Object err) {
        debugPrint('Stream app_config/android error: $err');
      },
    );

    // Lakukan pengecekan awal langsung dari server
    await checkForUpdate(manual: false);
  }

  void _applyRemoteInfo(AppUpdateInfo? info) {
    // Jangan ganggu status jika proses unduh/instal sedang berjalan untuk versi yang sama
    if (state.status == AppUpdateStatus.downloading) return;

    if (info == null) {
      state = state.copyWith(
        status: AppUpdateStatus.upToDate,
        clearUpdateInfo: true,
        clearErrorMessage: true,
      );
      return;
    }

    if (info.isUpdateAvailable(state.currentVersion)) {
      final isSameBuildAlreadyReady =
          state.status == AppUpdateStatus.readyToInstall &&
              state.updateInfo?.latestBuildNumber == info.latestBuildNumber &&
              state.downloadedApkPath != null;

      state = state.copyWith(
        status: isSameBuildAlreadyReady
            ? AppUpdateStatus.readyToInstall
            : AppUpdateStatus.available,
        updateInfo: info,
        clearErrorMessage: true,
      );
    } else {
      state = state.copyWith(
        status: AppUpdateStatus.upToDate,
        updateInfo: info,
        clearErrorMessage: true,
      );
    }
  }

  /// Mengecek pembaruan ke Firestore (otomatis saat startup atau manual dari Pengaturan)
  Future<AppUpdateStatus> checkForUpdate({bool manual = false}) async {
    if (state.status == AppUpdateStatus.downloading) {
      return state.status;
    }

    final current = await _service.getCurrentVersion();
    if (!mounted) return state.status;

    state = state.copyWith(
      status: AppUpdateStatus.checking,
      currentVersion: current,
      clearErrorMessage: true,
      clearDismissedBuildNumber: manual,
    );

    try {
      final info = await _service.fetchLatestUpdateInfo();
      if (!mounted) return state.status;
      _applyRemoteInfo(info);
      return state.status;
    } catch (e) {
      if (!mounted) return state.status;
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        status: manual ? AppUpdateStatus.error : AppUpdateStatus.idle,
        errorMessage: manual
            ? (cleanErr.isNotEmpty
                ? cleanErr
                : 'Gagal memeriksa pembaruan. Periksa koneksi internet Anda.')
            : null,
      );
      return state.status;
    }
  }

  /// Mengunduh file APK dari `downloadUrl` dan langsung memicu installer Android
  Future<void> startDownloadAndInstall() async {
    final info = state.updateInfo;
    if (info == null || !info.hasValidDownloadUrl) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Tautan file APK belum diatur dengan benar di Firebase.',
      );
      return;
    }

    if (state.status == AppUpdateStatus.downloading) return;

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      receivedBytes: 0,
      totalBytes: -1,
      clearErrorMessage: true,
      clearDownloadedApkPath: true,
    );

    var lastNotifiedBytes = 0;

    try {
      final apkPath = await _service.downloadApk(
        updateInfo: info,
        onProgress: (received, total) {
          if (!mounted) return;
          // Throttle pembaruan UI tiap ~64 KB agar render tetap mulus
          if (received - lastNotifiedBytes >= 65536 ||
              (total > 0 && received >= total)) {
            lastNotifiedBytes = received;
            state = state.copyWith(
              receivedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      if (!mounted) return;
      state = state.copyWith(
        downloadedApkPath: apkPath,
        receivedBytes: state.totalBytes > 0 ? state.totalBytes : state.receivedBytes,
      );

      await _triggerInstaller(apkPath);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (msg.toLowerCase().contains('dibatalkan')) {
        state = state.copyWith(
          status: AppUpdateStatus.available,
          receivedBytes: 0,
          totalBytes: -1,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: msg.isNotEmpty
              ? msg
              : 'Gagal mengunduh pembaruan. Silakan coba lagi.',
        );
      }
    }
  }

  Future<void> _triggerInstaller(String apkPath) async {
    final canInstall = await _service.canInstallPackages();
    if (!mounted) return;

    if (!canInstall) {
      state = state.copyWith(
        status: AppUpdateStatus.needsPermission,
        downloadedApkPath: apkPath,
        clearErrorMessage: true,
      );
      return;
    }

    state = state.copyWith(
      status: AppUpdateStatus.readyToInstall,
      downloadedApkPath: apkPath,
      clearErrorMessage: true,
    );

    try {
      await _service.installApk(apkPath);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage:
            'Gagal membuka installer Android: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Membuka pengaturan Android untuk mengizinkan instalasi APK dari SmartFi
  Future<void> openInstallPermissionSettings() async {
    try {
      await _service.openInstallPermissionSettings();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage:
            'Gagal membuka pengaturan izin: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Mencoba kembali meluncurkan installer untuk APK yang sudah terunduh
  Future<void> retryInstall() async {
    final path = state.downloadedApkPath;
    if (path == null) {
      await startDownloadAndInstall();
      return;
    }
    await _triggerInstaller(path);
  }

  void cancelDownload() {
    _service.cancelDownload();
  }

  void dismissOptionalUpdate() {
    if (state.isForceRequired) return;
    state = state.copyWith(
      dismissedBuildNumber: state.updateInfo?.latestBuildNumber,
    );
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _service.cancelDownload();
    super.dispose();
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  final service = ref.watch(appUpdateServiceProvider);
  return AppUpdateNotifier(service);
});
