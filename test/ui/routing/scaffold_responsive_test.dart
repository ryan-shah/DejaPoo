import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/notifications/fake_notification_service.dart';
import 'package:dejapoo/ui/routing/scaffold_with_nav_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shell_overrides.dart';

/// Builds a minimal GoRouter with a [StatefulShellRoute] wired to
/// [ScaffoldWithNavBar], using simple placeholder screens so this test does
/// not depend on the real feature screens (and their Drift providers).
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
                    const Center(child: Text('Home')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) =>
                    const Center(child: Text('Reports')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const Center(child: Text('Settings')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// [ScaffoldWithNavBar] is a `ConsumerWidget` since dp-2j9 (it watches the
/// sync-staleness reminder and activates `syncTriggerProvider`), so it needs a
/// ProviderScope with an in-memory database and a plugin-free auth notifier.
Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  AppDatabase db, {
  FakeNotificationService? notifications,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = _buildTestRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: shellOverrides(db, notificationService: notifications),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'narrow width shows NavigationBar, not NavigationRail',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(400, 800), db);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'wide width shows NavigationRail, not NavigationBar',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800), db);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'content is constrained to kContentMaxWidth at wide layouts',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800), db);

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final hasContentConstraint = constrainedBoxes.any(
        (box) => box.constraints.maxWidth == kContentMaxWidth,
      );
      expect(hasContentConstraint, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'tapping a NavigationRail destination navigates branches',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800), db);

      expect(find.text('Home'), findsWidgets);

      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  // Regression test for dp-5br: notificationPreferences' build() re-arms the
  // daily reminder, but nothing outside Settings used to read the provider, so
  // a reminder dropped by a reboot stayed dropped until the user happened to
  // open Settings. The shell must activate it on every launch.
  testWidgets(
    'mounting the shell re-arms an enabled daily reminder',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'notification_enabled': true,
        'notification_hour': 7,
        'notification_minute': 15,
      });
      final notifications = FakeNotificationService();

      await _pumpAtSize(
        tester,
        const Size(400, 800),
        db,
        notifications: notifications,
      );

      expect(notifications.scheduleCallCount, 1);
      expect(notifications.scheduledHour, 7);
      expect(notifications.scheduledMinute, 15);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
