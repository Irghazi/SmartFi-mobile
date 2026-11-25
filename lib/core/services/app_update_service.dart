import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/models/app_update_model.dart';

/// Layanan pemeriksaan versi otomatis dari Cloud Firestore (`app_config/android`),
/// pengunduhan APK dengan progress real-time, serta peluncuran installer Android.
class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel('com.smartfi.mobile/app_updater');
  static const String configCollection = 'app_config';
  static const String androidConfigDoc = 'android';

  http.Client? _activeDownloadClient;
  bool _isCancelled = false;

  /// Membaca nama versi dan build number aplikasi yang terpasang di Android
  Future<AppVersionInfo> getCurrentVersion() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
      if (result != null) {
        final versionName = (result['versionName'] as String?)?.trim();
        final buildNumber = (result['buildNumber'] as num?)?.toInt();
        if (versionName != null && versionName.isNotEmpty && buildNumber != null) {
          return AppVersionInfo(
            versionName: versionName,
            buildNumber: buildNumber,
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca versi aplikasi native: $e');
    }
    return const AppVersionInfo(versionName: '1.0.0', buildNumber: 1);
  }

  /// Mengambil konfigurasi pembaruan terbaru sekali jalan dari Firestore
  Future<AppUpdateInfo?> fetchLatestUpdateInfo() async {
    if (Firebase.apps.isEmpty) return null;

    final docRef = FirebaseFirestore.instance
        .collection(configCollection)
        .doc(androidConfigDoc);

    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      snapshot = await docRef.get().timeout(const Duration(seconds: 5));
    }

    if (!snapshot.exists || snapshot.data() == null) return null;
    return AppUpdateInfo.fromJson(snapshot.data()!);
  }

  /// Stream real-time konfigurasi pembaruan dari Firestore (`app_config/android`)
  Stream<AppUpdateInfo?> watchUpdateInfo() {
    if (Firebase.apps.isEmpty) {
      return const Stream<AppUpdateInfo?>.empty();
    }

    return FirebaseFirestore.instance
        .collection(configCollection)
        .doc(androidConfigDoc)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUpdateInfo.fromJson(snap.data()!);
    });
  }

  /// Mengecek apakah Android sudah mengizinkan instalasi APK dari aplikasi ini
  Future<bool> canInstallPackages() async {
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Membuka pengaturan Android "Instal Aplikasi Tidak Dikenal" untuk SmartFi
  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod('openInstallPermissionSettings');
  }

  /// Meluncurkan Android Package Installer untuk file APK lokal
  Future<void> installApk(String filePath) async {
    await _channel.invokeMethod('installApk', {'filePath': filePath});
  }

  /// Membatalkan proses unduhan APK yang sedang berjalan
  void cancelDownload() {
    _isCancelled = true;
    _activeDownloadClient?.close();
    _activeDownloadClient = null;
  }

  /// Mengunduh file APK ke folder cache `updates/` dengan pelaporan progress streaming
  Future<String> downloadApk({
    required AppUpdateInfo updateInfo,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    if (!updateInfo.hasValidDownloadUrl) {
      throw Exception('Tautan unduhan APK tidak valid pada konfigurasi Firebase.');
    }

    _isCancelled = false;
    final client = http.Client();
    _activeDownloadClient = client;

    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory('${tempDir.path}/updates');
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }

    // Bersihkan file APK lama agar penyimpanan tetap hemat
    await _cleanupOldApks(updatesDir);

    final safeVersion =
        updateInfo.latestVersion.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final targetPath =
        '${updatesDir.path}/smartfi_v${safeVersion}_b${updateInfo.latestBuildNumber}.apk';
    final tempFile = File('$targetPath.part');
    final finalFile = File(targetPath);

    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl.trim()));
      final response = await client.send(request).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengunduh APK (HTTP ${response.statusCode}). Periksa tautan di Firebase.',
        );
      }

      final totalBytes = response.contentLength ?? -1;
      int receivedBytes = 0;
      sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          throw Exception('Unduhan dibatalkan.');
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (_isCancelled) {
        throw Exception('Unduhan dibatalkan.');
      }

      final fileLength = await tempFile.length();
      if (fileLength < 1024) {
        throw Exception('File APK rusak atau terlalu kecil ($fileLength byte).');
      }

      // Validasi magic header ZIP/APK (`PK\x03\x04`) agar halaman HTML tidak lolos ke installer
      final headerBytes = await tempFile.openRead(0, 4).first;
      if (headerBytes.length < 4 ||
          headerBytes[0] != 0x50 ||
          headerBytes[1] != 0x4B ||
          headerBytes[2] != 0x03 ||
          headerBytes[3] != 0x04) {
        throw Exception(
          'Tautan bukan file APK langsung (terdeteksi halaman web/HTML). Pastikan downloadUrl adalah direct link file .apk.',
        );
      }

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);
      return finalFile.path;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
      if (identical(_activeDownloadClient, client)) {
        _activeDownloadClient = null;
      }
    }
  }

  Future<void> _cleanupOldApks(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.apk') || entity.path.endsWith('.part'))) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }
}
