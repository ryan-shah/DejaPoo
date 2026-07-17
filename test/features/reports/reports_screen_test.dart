import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/reports/reports_screen.dart';
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

  Future<void> pumpReportsScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> driftTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('selector shows all period kinds and defaults to Month',
      (WidgetTester tester) async {
    await pumpReportsScreen(tester);

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      tester.element(find.byType(ReportsScreen)),
    );
    final String expectedLabel = localizations.formatMonthYear(
      DateTime.now(),
    );
    expect(find.text(expectedLabel), findsOneWidget);

    await driftTeardown(tester);
  });

  testWidgets('tapping next/prev arrows updates the period label',
      (WidgetTester tester) async {
    await pumpReportsScreen(tester);

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      tester.element(find.byType(ReportsScreen)),
    );
    final DateTime now = DateTime.now();
    final String currentLabel = localizations.formatMonthYear(now);
    final DateTime nextMonthAnchor = DateTime(now.year, now.month + 1);
    final String nextLabel = localizations.formatMonthYear(nextMonthAnchor);

    expect(find.text(currentLabel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text(nextLabel), findsOneWidget);
    expect(find.text(currentLabel), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text(currentLabel), findsOneWidget);

    await driftTeardown(tester);
  });

  testWidgets('switching period kind changes the range',
      (WidgetTester tester) async {
    await pumpReportsScreen(tester);

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      tester.element(find.byType(ReportsScreen)),
    );
    final DateTime now = DateTime.now();
    final String monthLabel = localizations.formatMonthYear(now);
    expect(find.text(monthLabel), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.text(monthLabel), findsNothing);

    await driftTeardown(tester);
  });

  testWidgets('summary tab shows stat tiles', (WidgetTester tester) async {
    await repo.create(
      occurredAt: DateTime.now(),
      bristolType: BristolType.type4,
    );

    await pumpReportsScreen(tester);

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Avg/day'), findsOneWidget);
    expect(find.text('Most common'), findsOneWidget);
    expect(find.text('Healthy (3-5)'), findsOneWidget);
    expect(find.text('Longest gap'), findsOneWidget);

    await driftTeardown(tester);
  });

  testWidgets('tapping Custom opens the date range picker',
      (WidgetTester tester) async {
    await pumpReportsScreen(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // The date range picker dialog should now be showing.
    expect(find.byType(DateRangePickerDialog), findsOneWidget);

    // Dismiss it so teardown doesn't leave the dialog's own timers pending.
    Navigator.of(
      tester.element(find.byType(DateRangePickerDialog)),
    ).pop();
    await tester.pumpAndSettle();

    await driftTeardown(tester);
  });

  testWidgets('empty state renders without crashing',
      (WidgetTester tester) async {
    await pumpReportsScreen(tester);

    expect(find.text('No data'), findsWidgets);

    await driftTeardown(tester);
  });
}
