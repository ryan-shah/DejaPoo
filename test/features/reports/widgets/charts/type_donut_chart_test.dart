import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/widgets/charts/type_donut_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<BristolType, int> fixture = <BristolType, int>{
    BristolType.type3: 5,
    BristolType.type4: 3,
    BristolType.type1: 1,
  };

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders a pie chart with data', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(TypeDonutChart(distribution: fixture)));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
  });

  testWidgets('empty distribution renders gracefully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(const TypeDonutChart(distribution: <BristolType, int>{})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsNothing);
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('all-zero distribution renders gracefully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TypeDonutChart(
          distribution: <BristolType, int>{
            BristolType.type1: 0,
            BristolType.type2: 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsNothing);
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('legend shows correct labels and counts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(TypeDonutChart(distribution: fixture)));
    await tester.pumpAndSettle();

    expect(find.text('Type 3: 5'), findsOneWidget);
    expect(find.text('Type 4: 3'), findsOneWidget);
    expect(find.text('Type 1: 1'), findsOneWidget);
  });
}
