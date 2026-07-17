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
    // Let the stream emit its first value.
    await tester.pumpAndSettle();
  }

  /// Creates a single entry for today and returns it.
  Future<BowelMovement> createTodayEntry({
    BristolType type = BristolType.type4,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day, 10);
    return repo.create(occurredAt: today, bristolType: type);
  }

  group('Swipe actions', () {
    testWidgets('swipe left removes tile from the list',
        (WidgetTester tester) async {
      await createTodayEntry();
      await pumpHomeScreen(tester);

      // Verify the entry is visible
      expect(
        find.text('Type 4 — Smooth sausage'),
        findsOneWidget,
      );

      // Swipe left to delete
      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Tile should be gone
      expect(find.text('Type 4 — Smooth sausage'), findsNothing);

      // Drift teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('after delete, SnackBar shows with Undo action',
        (WidgetTester tester) async {
      await createTodayEntry();
      await pumpHomeScreen(tester);

      // Swipe left to delete
      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // SnackBar should appear with "Entry deleted" and "Undo"
      expect(find.text('Entry deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Drift teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('tapping Undo restores the deleted entry',
        (WidgetTester tester) async {
      await createTodayEntry();
      await pumpHomeScreen(tester);

      // Swipe left to delete
      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Verify deleted — tile gone, snackbar visible
      expect(find.text('Type 4 — Smooth sausage'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Entry should reappear
      expect(
        find.text('Type 4 — Smooth sausage'),
        findsOneWidget,
      );

      // Drift teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('swipe right opens the edit sheet',
        (WidgetTester tester) async {
      await createTodayEntry();
      await pumpHomeScreen(tester);

      // Swipe right to edit
      await tester.drag(
        find.text('Type 4 — Smooth sausage'),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      // The edit sheet should be visible with "Edit Entry" title
      expect(find.text('Edit Entry'), findsOneWidget);

      // Drift teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
