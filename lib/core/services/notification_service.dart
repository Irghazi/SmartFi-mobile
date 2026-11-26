import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/date_formatter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int _dailyReminderId = 1001;
  static const int _anomalyAlertId = 2001;
  static const int _testNotificationId = 3001;

  static const String _lastAnomalyDateKey = 'smartfi_anomaly_last_date';
  static const String _lastAnomalyAmountKey = 'smartfi_anomaly_last_amount';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final offsetHours = DateTime.now().timeZoneOffset.inHours;
        final locationName = switch (offsetHours) {
          8 => 'Asia/Makassar',
          9 => 'Asia/Jayapura',
          _ => 'Asia/Jakarta',
        };
        tz.setLocalLocation(tz.getLocation(locationName));
      } catch (_) {}

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(initSettings);
      await requestPermission();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inisialisasi NotificationService: $e');
    }
  }

  /// Meminta izin notifikasi Android 13+ secara aman
  Future<bool> requestPermission() async {
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> scheduleDailyReminder({
    required bool isEnabled,
    required String timeStr, // format "HH:mm"
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      // Batalkan jadwal pengingat sebelumnya
      await _notificationsPlugin.cancel(_dailyReminderId);

      if (!isEnabled) return;

      await requestPermission();

      final parts = timeStr.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'smartfi_reminder_channel',
        'Pengingat Harian SmartFi',
        channelDescription:
            'Pengingat harian untuk mencatat keuangan pribadi Anda di SmartFi.',
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        _dailyReminderId,
        'Catat Keuanganmu Hari Ini!',
        'Sudahkah kamu mencatat pengeluaran dan pemasukan hari ini di SmartFi?',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi harian: $e');
    }
  }

  /// Menampilkan notifikasi peringatan instan ketika pengeluaran hari ini terdeteksi anomali.
  /// Menggunakan deduplikasi cerdas per hari agar tidak berulang untuk nominal yang sama.
  Future<void> showSpendingAnomalyAlert({
    required String title,
    required String body,
    required int todayExpense,
    bool force = false,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final todayKey = DateFormatter.toIsoDateString(DateTime.now());
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final lastDate = prefs.getString(_lastAnomalyDateKey);
        final lastAmount = prefs.getInt(_lastAnomalyAmountKey) ?? 0;
        if (lastDate == todayKey && todayExpense <= lastAmount) {
          return;
        }
      }

      await prefs.setString(_lastAnomalyDateKey, todayKey);
      await prefs.setInt(_lastAnomalyAmountKey, todayExpense);

      final androidDetails = AndroidNotificationDetails(
        'smartfi_anomaly_channel',
        'Peringatan Anomali Pengeluaran',
        channelDescription:
            'Peringatan otomatis saat pengeluaran harianmu melonjak terlalu besar.',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      );

      await _notificationsPlugin.show(
        _anomalyAlertId,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi anomali: $e');
    }
  }

  /// Mengirim notifikasi uji coba untuk memverifikasi izin & tampilan notifikasi di perangkat
  Future<void> showTestNotification() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      await requestPermission();

      const androidDetails = AndroidNotificationDetails(
        'smartfi_reminder_channel',
        'Pengingat Harian SmartFi',
        channelDescription:
            'Pengingat harian untuk mencatat keuangan pribadi Anda di SmartFi.',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notificationsPlugin.show(
        _testNotificationId,
        'Notifikasi SmartFi Aktif!',
        'Pengingat harian & peringatan anomali pengeluaran siap bekerja di perangkatmu.',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Gagal mengirim notifikasi uji coba: $e');
    }
  }
}
