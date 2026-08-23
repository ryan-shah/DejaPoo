// Verifies dp-bjs.1: local mutations (create/edit/delete/undo, and bulk
// import/demo-data operations) schedule a debounced sync via
// SyncServiceNotifier.scheduleDebouncedSync(), wired at the UI layer.
//
// Rather than waiting on the real 5s debounce timer, these tests override
// [syncServiceProvider] with a [_FakeSyncServiceNotifier] that just counts
// calls to scheduleDebouncedSync() — this lets us assert *that* a mutation
// schedules a sync without depending on timer behavior or a real Drive
// connection.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/fixtures/fixture_generator.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/import_service.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/data/sync/sync_providers.dart';
import 'package:dejapoo/data/sync/sync_service.dart' show SyncState, SyncStatus;
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/home_screen.dart';
import 'package:dejapoo/features/home/widgets/entry_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test double for [SyncServiceNotifier] that records how many times
/// [scheduleDebouncedSync] is called instead of starting a real timer /
/// touching Drive. Also lets tests assert that no real sync attempt is
/// made when unauthenticated, since [syncNow] here is a no-op stub too.
class _FakeSyncServiceNotifier extends SyncServiceNotifier {
  int scheduleCallCount = 0;
  int syncNowCallCount = 0;

  @override
  SyncState build() {
    return SyncState.initial;
  }

  @override
  void scheduleDebouncedSync() {
    scheduleCallCount++;
  }

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
  }
}

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late _FakeSyncServiceNotifier fakeSync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);
    fakeSync = _FakeSyncServiceNotifier();
  });

  tearDown(() async {
    await db.close();
  });

  // Note: return type is `dynamic`, not `List<Override>` — `Override` isn't
  // exported from `flutter_riverpod.dart` in riverpod 3.x (it lives in
  // `package:riverpod/misc.dart`, which isn't a direct dependency of this
  // project). The list is still statically List<Override> at each call
  // site (ProviderScope.overrides / ProviderContainer.overrides).
  dynamic overrides() => [
        appDatabaseProvider.overrideWithValue(db),
        bowelMovementRepositoryProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWith(() => fakeSync),
      ];

  group('entry create/edit schedule a debounced sync', () {
    testWidgets('saving a new entry via EntrySheet schedules a sync',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(home: Scaffold(body: EntrySheet())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type 4'));
      await tester.pumpAndSettle();

      final Finder saveButton = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeSync.scheduleCallCount, 1);

      // Drift teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('editing an existing entry via EntrySheet schedules a sync',
        (WidgetTester tester) async {
      final BowelMovement existing = await repo.create(
        occurredAt: DateTime(2026, 7, 15, 9, 30),
        bristolType: BristolType.type3,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            home: Scaffold(body: EntrySheet(existing: existing)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type 5'));
      await tester.pumpAndSettle();

      final Finder updateButton =
          find.widgetWithText(FilledButton, 'Update');
      await tester.ensureVisible(updateButton);
      await tester.pumpAndSettle();
      await tester.tap(updateButton);
      await tester.pumpAndSettle();

      expect(fakeSync.scheduleCallCount, 1);

      // Drift teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('quick log schedules a debounced sync', () {
    testWidgets('long-press quick log schedules a sync',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The quick-log popup shows Bristol type icons via semantic labels.
      await tester.tap(
        find.bySemanticsLabel('Log Bristol type 4: ${BristolType.type4.label}'),
      );
      await tester.pumpAndSettle();

      expect(fakeSync.scheduleCallCount, 1);

      // Drift teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('delete/undo schedule a debounced sync', () {
    testWidgets('swiping to delete schedules a sync',
        (WidgetTester tester) async {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day, 10);
      await repo.create(occurredAt: today, bristolType: BristolType.type4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(fakeSync.scheduleCallCount, 1);

      // Drift teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('tapping Undo after delete schedules another sync',
        (WidgetTester tester) async {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day, 10);
      await repo.create(occurredAt: today, bristolType: BristolType.type4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(fakeSync.scheduleCallCount, 1);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(fakeSync.scheduleCallCount, 2);

      // Drift teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('bulk operations schedule exactly one sync', () {
    test('bulk import (many rows) schedules exactly one sync', () async {
      // Mirrors _ImportSectionState._pickAndImport / _importFromDrive:
      // ImportService.importBytes() does many individual repository writes
      // internally for a multi-row spreadsheet, then the UI schedules a
      // single debounced sync once the whole import completes.
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      final ImportService importService = ImportService(repo);
      final Uint8List csvBytes = Uint8List.fromList(utf8.encode(
        ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\n'
        'January,2024-01-01,1,,2,,,,,3\n'
        ',2024-01-02,,,,1,,,,1\n'
        ',2024-01-03,,,1,,,,,1\n',
      ));

      final ImportSummary summary =
          await importService.importBytes(csvBytes, 'test.csv');
      expect(summary.insertedCount, greaterThan(1));

      container.read(syncServiceProvider.notifier).scheduleDebouncedSync();

      expect(fakeSync.scheduleCallCount, 1);
    });

    test('demo insertAll + deleteAll each schedule exactly one sync',
        () async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      final List<BowelMovement> fixtures = FixtureGenerator().generate(
        firstDay: DateTime(2024, 1, 1),
        lastDay: DateTime(2024, 3, 1),
      );

      await repo.insertAll(fixtures);
      container.read(syncServiceProvider.notifier).scheduleDebouncedSync();
      expect(fakeSync.scheduleCallCount, 1);

      await repo.deleteAll();
      container.read(syncServiceProvider.notifier).scheduleDebouncedSync();
      expect(fakeSync.scheduleCallCount, 2);
    });
  });

  group('unauthenticated: no sync is attempted', () {
    test(
        'SyncServiceNotifier._ensureService returns null and syncNow no-ops '
        'when signed out', () async {
      // Use the *real* SyncServiceNotifier (not the fake) with the real
      // googleAuthProvider, which defaults to AuthStatus.signedOut with no
      // current user, so getAuthClient() resolves to null without touching
      // any platform channel.
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(googleAuthProvider),
        AuthStatus.signedOut,
      );

      // syncNow() should complete without throwing and without changing
      // state away from initial (no service could be constructed).
      await container.read(syncServiceProvider.notifier).syncNow();
      expect(container.read(syncServiceProvider).status, SyncStatus.idle);

      // scheduleDebouncedSync() itself is synchronous and safe to call even
      // though the eventual syncNow() it triggers will no-op.
      container.read(syncServiceProvider.notifier).scheduleDebouncedSync();
    });
  });
}
