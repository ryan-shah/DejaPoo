import 'package:dejapoo/data/notifications/notification_service.dart';

/// In-memory [NotificationService] fake for unit tests. Records calls and
/// lets tests control whether permission requests succeed.
class FakeNotificationService implements NotificationService {
  bool initializeCalled = false;
  bool permissionGranted = true;
  int requestPermissionCallCount = 0;

  int? scheduledHour;
  int? scheduledMinute;
  int scheduleCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    scheduledHour = hour;
    scheduledMinute = minute;
    scheduleCallCount++;
  }

  @override
  Future<void> cancelDailyReminder() async {
    scheduledHour = null;
    scheduledMinute = null;
    cancelCallCount++;
  }

  @override
  Future<bool> isScheduled() async {
    return scheduledHour != null;
  }
}
