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

  testWidgets('empty state renders when no entries exist',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('Tap + to log your first movement'), findsOneWidget);
    expect(find.text('No movements today'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('today header shows correct count after adding entries',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime todayMorning = DateTime(now.year, now.month, now.day, 8, 30);

    await repo.create(
      occurredAt: todayMorning,
      bristolType: BristolType.type4,
    );
    await repo.create(
      occurredAt: todayMorning.add(const Duration(hours: 2)),
      bristolType: BristolType.type3,
    );

    await pumpHomeScreen(tester);

    expect(find.text('2 movements today'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('entry tile shows Bristol type icon and time',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime todayMorning = DateTime(now.year, now.month, now.day, 9, 15);

    await repo.create(
      occurredAt: todayMorning,
      bristolType: BristolType.type4,
    );

    await pumpHomeScreen(tester);

    // Bristol type label should be visible
    expect(
      find.textContaining('Type 4'),
      findsWidgets,
    );
    expect(find.textContaining('Smooth sausage'), findsOneWidget);

    // Time should be formatted (9:15 AM in the default locale)
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(tester.element(find.byType(HomeScreen)));
    final String expectedTime = localizations.formatTimeOfDay(
      const TimeOfDay(hour: 9, minute: 15),
    );
    expect(find.text(expectedTime), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('entries are grouped by day with date headers',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day, 10);
    final DateTime yesterday =
        today.subtract(const Duration(days: 1));

    await repo.create(
      occurredAt: today,
      bristolType: BristolType.type4,
    );
    await repo.create(
      occurredAt: yesterday,
      bristolType: BristolType.type5,
    );

    await pumpHomeScreen(tester);

    // Should see "Today" and "Yesterday" section headers
    expect(find.text('Today'), findsWidgets); // "Today" in header card too
    expect(find.text('Yesterday'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dateOnly entries show "All day" instead of time',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day, 12);

    await repo.create(
      occurredAt: today,
      bristolType: BristolType.type2,
      dateOnly: true,
    );

    await pumpHomeScreen(tester);

    expect(find.text('All day'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('FAB tap opens the entry sheet', (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    // Tap the FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // The entry sheet should be visible with "New Entry" title
    expect(find.text('New Entry'), findsOneWidget);

    // Drift teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
