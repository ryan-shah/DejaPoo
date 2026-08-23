import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'sync_reminder_preferences.g.dart';

const String _snoozedUntilKey = 'sync_reminder_snoozed_until';

/// How long the "Later" action silences the staleness reminder for.
const Duration kSyncReminderSnoozeDuration = Duration(hours: 24);

/// Persisted state of the sync-staleness reminder. Device-local only (backed
/// by `shared_preferences`) — this must NEVER be included in the Google Drive
/// sync snapshot, which only carries `BowelMovement` records. A snooze is a
/// property of *this device's* nagging, not of the user's data.
class SyncReminderPreferences {
  const SyncReminderPreferences({this.snoozedUntil});

  /// UTC instant until which the reminder stays hidden, or `null` if the
  /// reminder has never been snoozed.
  ///
  /// Stored (and compared) as a UTC instant, matching `lastSyncAt` — per the
  /// `drift-flutter` skill, sync/audit timestamps are instants, not calendar
  /// wall time.
  final DateTime? snoozedUntil;

  /// Whether the reminder is currently suppressed at [nowUtc].
  bool isSnoozedAt(DateTime nowUtc) {
    final DateTime? until = snoozedUntil;
    if (until == null) return false;
    return nowUtc.toUtc().isBefore(until);
  }
}

/// Reads/writes the sync-staleness reminder snooze in `shared_preferences`.
@Riverpod(keepAlive: true)
class SyncReminderPreferencesNotifier
    extends _$SyncReminderPreferencesNotifier {
  @override
  Future<SyncReminderPreferences> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_snoozedUntilKey);
    return SyncReminderPreferences(
      snoozedUntil: raw == null ? null : DateTime.tryParse(raw)?.toUtc(),
    );
  }

  /// Hides the reminder for [kSyncReminderSnoozeDuration] from now.
  Future<void> snooze() async {
    final DateTime until =
        DateTime.now().toUtc().add(kSyncReminderSnoozeDuration);
    state = AsyncData<SyncReminderPreferences>(
      SyncReminderPreferences(snoozedUntil: until),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snoozedUntilKey, until.toIso8601String());
  }

  /// Clears any active snooze (e.g. after a successful manual sync).
  Future<void> clearSnooze() async {
    state = const AsyncData<SyncReminderPreferences>(
      SyncReminderPreferences(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snoozedUntilKey);
  }
}
