import 'package:dejapoo/data/notifications/notification_providers.dart';
import 'package:dejapoo/data/notifications/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_preferences.g.dart';

const String _enabledKey = 'notification_enabled';
const String _hourKey = 'notification_hour';
const String _minuteKey = 'notification_minute';

/// Persisted daily-reminder preference. Device-local only (backed by
/// `shared_preferences`) — this must NEVER be included in the Google Drive
/// sync snapshot, which only carries [BowelMovement] records.
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  NotificationPreferences copyWith({bool? enabled, int? hour, int? minute}) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

/// Manages the daily reminder preference: reads/writes `shared_preferences`
/// and drives the [NotificationService] to schedule/cancel/reschedule as the
/// preference changes.
@Riverpod(keepAlive: true)
class NotificationPreferencesNotifier extends _$NotificationPreferencesNotifier {
  @override
  Future<NotificationPreferences> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final NotificationPreferences loaded = NotificationPreferences(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 9,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );

    // Re-assert the schedule on app start so it survives reinstalled
    // alarms (e.g. after a device reboot on platforms without boot-persisted
    // exact alarms, or a fresh app launch).
    if (loaded.enabled) {
      final NotificationService? service = ref.read(notificationServiceProvider);
      if (service != null) {
        await service.initialize();
        await service.scheduleDailyReminder(loaded.hour, loaded.minute);
      }
    }

    return loaded;
  }

  /// Enables or disables the daily reminder.
  ///
  /// When enabling, requests notification permission first; if denied, the
  /// preference is left/reverted to disabled and `false` is returned so the
  /// UI can inform the user. Returns `true` on success (or when disabling).
  Future<bool> setEnabled(bool enabled) async {
    final NotificationPreferences current =
        state.value ?? const NotificationPreferences();
    final NotificationService? service = ref.read(notificationServiceProvider);

    if (!enabled) {
      await service?.cancelDailyReminder();
      final NotificationPreferences updated = current.copyWith(enabled: false);
      state = AsyncData<NotificationPreferences>(updated);
      await _persist(updated);
      return true;
    }

    if (service == null) {
      // No platform support (e.g. web) — nothing to enable.
      return false;
    }

    await service.initialize();
    final bool granted = await service.requestPermission();
    if (!granted) {
      final NotificationPreferences reverted =
          current.copyWith(enabled: false);
      state = AsyncData<NotificationPreferences>(reverted);
      await _persist(reverted);
      return false;
    }

    await service.scheduleDailyReminder(current.hour, current.minute);
    final NotificationPreferences updated = current.copyWith(enabled: true);
    state = AsyncData<NotificationPreferences>(updated);
    await _persist(updated);
    return true;
  }

  /// Updates the reminder time. Reschedules immediately if currently
  /// enabled.
  Future<void> setTime(int hour, int minute) async {
    final NotificationPreferences current =
        state.value ?? const NotificationPreferences();
    final NotificationPreferences updated =
        current.copyWith(hour: hour, minute: minute);
    state = AsyncData<NotificationPreferences>(updated);
    await _persist(updated);

    if (updated.enabled) {
      final NotificationService? service = ref.read(notificationServiceProvider);
      await service?.scheduleDailyReminder(hour, minute);
    }
  }

  Future<void> _persist(NotificationPreferences prefs) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setBool(_enabledKey, prefs.enabled);
    await sp.setInt(_hourKey, prefs.hour);
    await sp.setInt(_minuteKey, prefs.minute);
  }
}
