import 'package:dejapoo/data/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Real [NotificationService] backed by `flutter_local_notifications` and
/// `timezone`.
///
/// iOS note: this app is developed on a Windows machine and iOS scheduling
/// is not exercised here. Shipping to iOS additionally requires configuring
/// `AppDelegate.swift` (registering `UNUserNotificationCenter` delegate) and
/// enabling the "Background Modes" / notification capabilities in Xcode —
/// see the flutter_local_notifications README's iOS setup section.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const int _dailyReminderId = 0;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily Reminder';
  static const String _channelDescription =
      'Daily reminder to log bowel movements';

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // `DateTime.now().timeZoneName` must NOT be used here: on Android it
    // yields an abbreviation or offset ('PDT', 'GMT+05:30') rather than an
    // IANA name, so `tz.getLocation` throws and `tz.local` silently stays
    // UTC — which anchors every reminder to the wrong wall-clock time.
    // `flutter_timezone` returns the real IANA id ('America/Los_Angeles').
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error, stackTrace) {
      // Fall back to UTC if the platform timezone can't be resolved (e.g.
      // some CI/emulator environments). Scheduling still works, just
      // anchored to UTC — log it so the misfire is diagnosable.
      debugPrint('Failed to resolve local timezone, using UTC: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await initialize();

    final tz.TZDateTime scheduled = _nextInstanceOf(hour, minute);

    await _plugin.zonedSchedule(
      _dailyReminderId,
      "Log today's movements",
      "Don't forget to log today's bowel movements in DejaPoo.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(_dailyReminderId);
  }

  @override
  Future<bool> isScheduled() async {
    await initialize();
    final List<PendingNotificationRequest> pending =
        await _plugin.pendingNotificationRequests();
    return pending.any((PendingNotificationRequest r) => r.id == _dailyReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
