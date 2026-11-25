import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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

      // Minta izin notifikasi untuk Android 13+
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inisialisasi NotificationService: $e');
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
      await _notificationsPlugin.cancel(1001);

      if (!isEnabled) return;

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
        1001,
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
}
