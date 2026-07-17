import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/reports/widgets/reports_list_tab.dart';
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

  Future<void> pumpListTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ReportsListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> driftTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('list shows entries within the selected range',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day, 9);

    await repo.create(occurredAt: today, bristolType: BristolType.type4);
    await repo.create(
      occurredAt: today.add(const Duration(hours: 1)),
      bristolType: BristolType.type5,
    );

    await pumpListTab(tester);

    expect(find.text('2 entries'), findsOneWidget);
    expect(find.textContaining('Type 4'), findsWidgets);
    expect(find.textContaining('Type 5'), findsWidgets);

    await driftTeardown(tester);
  });

  testWidgets('toggling filter chips narrows the list',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day, 9);

    await repo.create(occurredAt: today, bristolType: BristolType.type4);
    await repo.create(
      occurredAt: today.add(const Duration(hours: 1)),
      bristolType: BristolType.type7,
    );

    await pumpListTab(tester);

    expect(find.text('2 entries'), findsOneWidget);
    expect(find.textContaining('Type 4 — '), findsOneWidget);
    expect(find.textContaining('Type 7 — '), findsOneWidget);

    // Deselect the "Type 7" filter chip.
    await tester.tap(find.widgetWithText(FilterChip, 'Type 7'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 2 entries'), findsOneWidget);
    expect(find.textContaining('Type 7 — '), findsNothing);
    expect(find.textContaining('Type 4 — '), findsOneWidget);

    await driftTeardown(tester);
  });

  testWidgets('empty state renders', (WidgetTester tester) async {
    await pumpListTab(tester);

    expect(find.text('No entries'), findsOneWidget);

    await driftTeardown(tester);
  });
}
