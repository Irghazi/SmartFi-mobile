import 'package:cloud_firestore/cloud_firestore.dart';

/// Informasi versi aplikasi yang sedang terpasang di perangkat
class AppVersionInfo {
  final String versionName;
  final int buildNumber;

  const AppVersionInfo({
    required this.versionName,
    required this.buildNumber,
  });

  String get displayLabel => 'v$versionName (Build $buildNumber)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppVersionInfo &&
        other.versionName == versionName &&
        other.buildNumber == buildNumber;
  }

  @override
  int get hashCode => Object.hash(versionName, buildNumber);
}

/// Metadata rilis terbaru yang diambil dari Cloud Firestore (`app_config/android`)
class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final int minSupportedBuildNumber;
  final bool forceUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final DateTime? updatedAt;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    this.minSupportedBuildNumber = 1,
    this.forceUpdate = false,
    this.releaseNotes = '',
    required this.downloadUrl,
    this.updatedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    int parseInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? fallback;
      return fallback;
    }

    final rawVersion = (json['latestVersion'] ?? json['latest_version'] ?? '')
        .toString()
        .trim();
    final rawBuild = json['latestBuildNumber'] ?? json['latest_build_number'];
    final rawMinBuild =
        json['minSupportedBuildNumber'] ?? json['min_supported_build_number'];
    final rawForce = json['forceUpdate'] ?? json['force_update'];
    final rawNotes =
        (json['releaseNotes'] ?? json['release_notes'] ?? '').toString().trim();
    final rawUrl =
        (json['downloadUrl'] ?? json['download_url'] ?? '').toString().trim();

    return AppUpdateInfo(
      latestVersion: rawVersion.isNotEmpty ? rawVersion : '1.0.0',
      latestBuildNumber: parseInt(rawBuild, 1),
      minSupportedBuildNumber: parseInt(rawMinBuild, 1),
      forceUpdate: rawForce == true,
      releaseNotes: rawNotes,
      downloadUrl: rawUrl,
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  bool get hasValidDownloadUrl {
    final uri = Uri.tryParse(downloadUrl.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Membandingkan dua string semver (`1.2.0` vs `1.10.0`).
  /// Mengembalikan > 0 jika [a] lebih baru dari [b], 0 jika sama, < 0 jika lebih lama.
  static int compareVersions(String a, String b) {
    List<int> parseParts(String version) {
      final clean = version.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      return clean
          .split('.')
          .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final partsA = parseParts(a);
    final partsB = parseParts(b);
    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (int i = 0; i < maxLen; i++) {
      final valA = i < partsA.length ? partsA[i] : 0;
      final valB = i < partsB.length ? partsB[i] : 0;
      if (valA != valB) return valA.compareTo(valB);
    }
    return 0;
  }

  /// Apakah tersedia versi lebih baru dibanding versi terpasang saat ini
  bool isUpdateAvailable(AppVersionInfo current) {
    if (!hasValidDownloadUrl) return false;
    if (latestBuildNumber > current.buildNumber) return true;
    if (latestBuildNumber == current.buildNumber &&
        compareVersions(latestVersion, current.versionName) > 0) {
      return true;
    }
    return false;
  }

  /// Apakah pengguna wajib memperbarui aplikasi (tidak bisa dilewati)
  bool isForceRequired(AppVersionInfo current) {
    if (!isUpdateAvailable(current)) return false;
    return forceUpdate || current.buildNumber < minSupportedBuildNumber;
  }
}
