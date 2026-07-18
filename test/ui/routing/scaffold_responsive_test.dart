import 'package:dejapoo/ui/routing/scaffold_with_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = _buildTestRouter();
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'narrow width shows NavigationBar, not NavigationRail',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(400, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets(
    'wide width shows NavigationRail, not NavigationBar',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'content is constrained to kContentMaxWidth at wide layouts',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800));

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final hasContentConstraint = constrainedBoxes.any(
        (box) => box.constraints.maxWidth == kContentMaxWidth,
      );
      expect(hasContentConstraint, isTrue);
    },
  );

  testWidgets(
    'tapping a NavigationRail destination navigates branches',
    (WidgetTester tester) async {
      await _pumpAtSize(tester, const Size(1200, 800));

      expect(find.text('Home'), findsWidgets);

      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsWidgets);
    },
  );
}
