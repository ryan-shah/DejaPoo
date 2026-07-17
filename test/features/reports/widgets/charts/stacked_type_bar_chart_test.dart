import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/widgets/charts/stacked_type_bar_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime week1 = DateTime(2026, 7, 6);
  final DateTime week2 = DateTime(2026, 7, 13);

  final List<PeriodTypeCount> fixture = <PeriodTypeCount>[
    PeriodTypeCount(
      periodStart: week1,
      type: BristolType.type3,
      count: 3,
    ),
    PeriodTypeCount(
      periodStart: week1,
      type: BristolType.type4,
      count: 2,
    ),
    PeriodTypeCount(
      periodStart: week2,
      type: BristolType.type1,
      count: 1,
    ),
  ];

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders a bar chart with data', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        StackedTypeBarChart(
          buckets: fixture,
          periodLabels: const <String>['Jul 6', 'Jul 13'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('empty data does not crash and shows a message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const StackedTypeBarChart(
          buckets: <PeriodTypeCount>[],
          periodLabels: <String>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('legend shows type labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        StackedTypeBarChart(
          buckets: fixture,
          periodLabels: const <String>['Jul 6', 'Jul 13'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final BristolType type in BristolType.values) {
      expect(find.text('Type ${type.number}'), findsOneWidget);
    }
  });
}
