import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('FAB tap opens the add entry sheet',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Entry'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('FAB long-press shows quick-log popup with 7 Bristol types',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // The popup should show "Quick log" label
    expect(find.text('Quick log'), findsOneWidget);

    // All 7 Bristol type icons should be present (via semantic labels)
    for (int i = 1; i <= 7; i++) {
      expect(
        find.bySemanticsLabel('Log Bristol type $i'),
        findsOneWidget,
      );
    }

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'tapping a type in quick-log popup creates entry and shows SnackBar',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    // Long-press FAB to show the popup
    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Tap Bristol type 4 icon
    await tester.tap(find.bySemanticsLabel('Log Bristol type 4'));
    await tester.pumpAndSettle();

    // Popup should be dismissed
    expect(find.text('Quick log'), findsNothing);

    // SnackBar should confirm the log
    expect(find.text('Type 4 logged'), findsOneWidget);

    // Verify an entry was created in the database
    final DateTime now = DateTime.now();
    final List<BowelMovement> entries = await repo.getRange(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
    expect(entries.length, 1);
    expect(entries.first.bristolType, BristolType.type4);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
