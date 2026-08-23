// Verifies dp-2j9: the staleness banner renders inside the app shell, above
// the per-screen scaffolds, in BOTH the narrow (NavigationBar) and the wide
// (NavigationRail) layout branch.
import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/data/sync/sync_reminder.dart';
import 'package:dejapoo/data/sync/sync_reminder_preferences.dart';
import 'package:dejapoo/data/sync/sync_service.dart' show kLastSyncAtKey;
import 'package:dejapoo/ui/routing/scaffold_with_nav_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shell_overrides.dart';

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const Center(child: Text('HomeBody')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) =>
                    const Center(child: Text('ReportsBody')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const Center(child: Text('SettingsBody')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
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

  /// Primes the reminder providers off-tree so the banner's inputs are
  /// resolved (not `AsyncLoading`) by the time the shell is pumped.
  Future<ProviderContainer> primedContainer() async {
    final container = ProviderContainer(overrides: shellOverrides(db));
    addTearDown(container.dispose);
    await container.read(persistedLastSyncAtProvider.future);
    await container.read(syncReminderPreferencesProvider.future);
    return container;
  }

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = await primedContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _buildTestRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> setLastSyncDaysAgo(int days) async {
    await repo.set(
      kLastSyncAtKey,
      DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String(),
    );
  }

  testWidgets('stale data shows the banner in the narrow layout',
      (WidgetTester tester) async {
    await setLastSyncDaysAgo(5);

    await pumpShell(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text("Your data hasn't synced in 5 days"), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('stale data shows the banner in the wide layout',
      (WidgetTester tester) async {
    await setLastSyncDaysAgo(5);

    await pumpShell(tester, const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text("Your data hasn't synced in 5 days"), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('fresh data shows no banner', (WidgetTester tester) async {
    await setLastSyncDaysAgo(1);

    await pumpShell(tester, const Size(400, 800));

    expect(find.byType(MaterialBanner), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('never-synced user is never nagged', (WidgetTester tester) async {
    await pumpShell(tester, const Size(400, 800));

    expect(find.byType(MaterialBanner), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('tapping Later snoozes the banner away',
      (WidgetTester tester) async {
    await setLastSyncDaysAgo(5);

    await pumpShell(tester, const Size(400, 800));
    expect(find.byType(MaterialBanner), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('Sync now routes an unauthorized user to Settings',
      (WidgetTester tester) async {
    await setLastSyncDaysAgo(5);

    await pumpShell(tester, const Size(400, 800));

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('SettingsBody'), findsOneWidget);

    await teardownTree(tester);
  });
}
