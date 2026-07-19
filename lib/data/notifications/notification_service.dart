/// Abstraction over local notification scheduling so the daily reminder
/// logic (schedule/cancel/reschedule) is unit-testable without a platform
/// channel.
abstract class NotificationService {
  /// Performs one-time setup (timezone data, plugin initialization,
  /// notification channel creation). Safe to call multiple times.
  Future<void> initialize();

  /// Requests the runtime notification permission (Android 13+, iOS).
  /// Returns `true` if permission is granted.
  Future<bool> requestPermission();

  /// Schedules (or reschedules) the daily reminder notification for the
  /// given local [hour]/[minute] (24h clock). Uses inexact zoned scheduling
  /// so it does not require the `SCHEDULE_EXACT_ALARM` permission.
  Future<void> scheduleDailyReminder(int hour, int minute);

  /// Cancels the daily reminder notification, if scheduled.
  Future<void> cancelDailyReminder();

  /// Whether the daily reminder is currently scheduled.
  Future<bool> isScheduled();
}
