import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/charts/stacked_type_bar_chart.dart';
import 'package:dejapoo/features/reports/widgets/charts/type_donut_chart.dart';
import 'package:dejapoo/features/reports/widgets/report_share_card.dart';
import 'package:dejapoo/features/reports/widgets/stat_tiles.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ReportStats _stats = ReportStats(
  total: 12,
  averagePerDay: 1.5,
  mostCommonType: BristolType.type4,
  healthyPercentage: 75,
  longestGapDays: 2,
);

const Map<BristolType, int> _distribution = <BristolType, int>{
  BristolType.type3: 3,
  BristolType.type4: 8,
  BristolType.type6: 1,
};

final List<PeriodTypeCount> _buckets = <PeriodTypeCount>[
  PeriodTypeCount(
    periodStart: DateTime(2026, 7, 6),
    type: BristolType.type4,
    count: 5,
  ),
  PeriodTypeCount(
    periodStart: DateTime(2026, 7, 13),
    type: BristolType.type3,
    count: 3,
  ),
];

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

ReportShareCard _card({bool showBarChart = true}) => ReportShareCard(
      rangeLabel: 'July 2026',
      generatedOn: DateTime(2026, 8, 23),
      stats: _stats,
      distribution: _distribution,
      buckets: _buckets,
      periodLabels: const <String>['7/6', '7/13'],
      showBarChart: showBarChart,
    );

void main() {
  testWidgets('renders the app name, range label and generated-on line',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();

    expect(find.text('DejaPoo'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
    expect(
      find.textContaining('Generated on'),
      findsOneWidget,
    );
  });

  testWidgets('renders the stat tiles', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();

    expect(find.byType(StatTiles), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Avg/day'), findsOneWidget);
    expect(find.text('Most common'), findsOneWidget);
    expect(find.text('Healthy (3-5)'), findsOneWidget);
    expect(find.text('Longest gap'), findsOneWidget);
  });

  testWidgets('renders both charts', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();

    expect(find.byType(StackedTypeBarChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(TypeDonutChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Bristol type by period'), findsOneWidget);
    expect(find.text('Bristol type distribution'), findsOneWidget);
  });

  testWidgets('omits the bar chart when showBarChart is false',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_card(showBarChart: false)));
    await tester.pumpAndSettle();

    expect(find.byType(StackedTypeBarChart), findsNothing);
    expect(find.byType(TypeDonutChart), findsOneWidget);
  });

  testWidgets('lays out at the fixed share width', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();

    final Size size = tester.getSize(find.byType(ReportShareCard));
    expect(size.width, reportShareCardWidth);
  });
}
