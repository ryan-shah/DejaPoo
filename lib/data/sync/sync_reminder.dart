import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/data/sync/sync_providers.dart';
import 'package:dejapoo/data/sync/sync_reminder_preferences.dart';
import 'package:dejapoo/data/sync/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_reminder.g.dart';

/// How long the user's Drive data may go unsynced before the app prompts.
const Duration kSyncStalenessThreshold = Duration(days: 3);

/// The last successful sync instant, read straight from the drift
/// `SyncStates` key/value table.
///
/// Deliberately *not* sourced from [SyncState.lastSyncAt]: that field is only
/// populated once a [SyncService] has been constructed, which requires a
/// Google auth client. A signed-out user would therefore always look like they
/// had never synced — exactly the case the reminder needs to detect.
///
/// The stored value is an ISO-8601 **UTC** instant (see [kLastSyncAtKey]);
/// it is normalized with `.toUtc()` so all comparisons stay UTC-to-UTC.
@Riverpod(keepAlive: true)
Future<DateTime?> persistedLastSyncAt(Ref ref) async {
  // Re-read whenever the sync service reports a state change, so a successful
  // sync clears the banner without an app restart.
  ref.watch(syncServiceProvider);

  final DriftSyncStateRepository repo = ref.watch(syncStateRepositoryProvider);
  final String? raw = await repo.get(kLastSyncAtKey);
  if (raw == null) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

/// Whether the staleness reminder should be shown, and how stale the data is.
class SyncReminderStatus {
  const SyncReminderStatus({
    required this.shouldShow,
    this.daysSinceLastSync,
  });

  /// Nothing to nag about.
  static const SyncReminderStatus hidden =
      SyncReminderStatus(shouldShow: false);

  final bool shouldShow;

  /// Whole days elapsed since the last successful sync, or `null` when
  /// [shouldShow] is false.
  final int? daysSinceLastSync;
}

/// Decides whether to prompt the user about stale Drive data.
///
/// Shows only when a `lastSyncAt` value **exists** and is older than
/// [kSyncStalenessThreshold]. A user who has never synced (never signed in,
/// or signed in but never completed a cycle) is never nagged — there is no
/// "your data hasn't synced" story to tell them yet. A snooze from the
/// "Later" action suppresses it until it expires.
@Riverpod(keepAlive: true)
SyncReminderStatus syncReminder(Ref ref) {
  final DateTime? lastSyncAt = ref.watch(persistedLastSyncAtProvider).value;
  if (lastSyncAt == null) {
    // Either still loading, or never synced — either way, no prompt.
    return SyncReminderStatus.hidden;
  }

  final SyncReminderPreferences? prefs =
      ref.watch(syncReminderPreferencesProvider).value;
  if (prefs == null) return SyncReminderStatus.hidden; // still loading

  final DateTime now = DateTime.now().toUtc();
  if (prefs.isSnoozedAt(now)) return SyncReminderStatus.hidden;

  final Duration elapsed = now.difference(lastSyncAt);
  if (elapsed < kSyncStalenessThreshold) return SyncReminderStatus.hidden;

  return SyncReminderStatus(
    shouldShow: true,
    daysSinceLastSync: elapsed.inDays,
  );
}
