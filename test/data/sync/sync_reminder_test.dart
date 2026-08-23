// Verifies dp-2j9: the app prompts when the user's Drive data hasn't synced
// in kSyncStalenessThreshold (3 days).
//
// The decision deliberately reads the persisted `lastSyncAt` out of the drift
// SyncStates key/value table rather than SyncState.lastSyncAt, because the
// latter is null whenever the user is signed out (no auth client => no
// SyncService). These tests therefore never construct a SyncService at all.
import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/data/sync/sync_reminder.dart';
import 'package:dejapoo/data/sync/sync_reminder_preferences.dart';
import 'package:dejapoo/data/sync/sync_service.dart' show kLastSyncAtKey;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftSyncStateRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSyncStateRepository(db);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await db.close();
  });

  /// Builds a container over the in-memory sync-state repository and resolves
  /// both async inputs of [syncReminderProvider] before returning it.
  Future<SyncReminderStatus> readStatus() async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncStateRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(persistedLastSyncAtProvider.future);
    await container.read(syncReminderPreferencesProvider.future);
    return container.read(syncReminderProvider);
  }

  Future<void> setLastSyncDaysAgo(double days) async {
    final DateTime when = DateTime.now().toUtc().subtract(
          Duration(minutes: (days * 24 * 60).round()),
        );
    await repo.set(kLastSyncAtKey, when.toIso8601String());
  }

  test('threshold is 3 days', () {
    expect(kSyncStalenessThreshold, const Duration(days: 3));
  });

  test('2 days since last sync => no banner', () async {
    await setLastSyncDaysAgo(2);

    final SyncReminderStatus status = await readStatus();

    expect(status.shouldShow, isFalse);
  });

  test('4 days since last sync => banner, reporting 4 days', () async {
    await setLastSyncDaysAgo(4);

    final SyncReminderStatus status = await readStatus();

    expect(status.shouldShow, isTrue);
    expect(status.daysSinceLastSync, 4);
  });

  test('no stored lastSyncAt at all => no banner (never nag a new user)',
      () async {
    expect(await repo.get(kLastSyncAtKey), isNull);

    final SyncReminderStatus status = await readStatus();

    expect(status.shouldShow, isFalse);
  });

  test('stale but snoozed => no banner', () async {
    await setLastSyncDaysAgo(10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sync_reminder_snoozed_until': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 12))
          .toIso8601String(),
    });

    final SyncReminderStatus status = await readStatus();

    expect(status.shouldShow, isFalse);
  });

  test('stale with an expired snooze => banner', () async {
    await setLastSyncDaysAgo(10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sync_reminder_snoozed_until': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

    final SyncReminderStatus status = await readStatus();

    expect(status.shouldShow, isTrue);
    expect(status.daysSinceLastSync, 10);
  });

  test('snooze() persists a 24h suppression window', () async {
    await setLastSyncDaysAgo(10);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncStateRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(persistedLastSyncAtProvider.future);
    await container.read(syncReminderPreferencesProvider.future);
    expect(container.read(syncReminderProvider).shouldShow, isTrue);

    await container.read(syncReminderPreferencesProvider.notifier).snooze();
    expect(container.read(syncReminderProvider).shouldShow, isFalse);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('sync_reminder_snoozed_until');
    expect(raw, isNotNull);
    final DateTime until = DateTime.parse(raw!).toUtc();
    final Duration remaining = until.difference(DateTime.now().toUtc());
    expect(remaining, lessThanOrEqualTo(kSyncReminderSnoozeDuration));
    expect(remaining, greaterThan(const Duration(hours: 23)));
  });
}
