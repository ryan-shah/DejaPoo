import 'dart:typed_data';

import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/report_share_card.dart';
import 'package:dejapoo/features/reports/widgets/share_report_sheet.dart';
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

Widget _wrap() => MaterialApp(
      home: Scaffold(
        body: ShareReportSheet(
          rangeLabel: 'July 2026',
          firstDay: DateTime(2026, 7),
          lastDay: DateTime(2026, 7, 31),
          generatedOn: DateTime(2026, 8, 23),
          stats: _stats,
          distribution: _distribution,
          buckets: _buckets,
          periodLabels: const <String>['7/6', '7/13'],
        ),
      ),
    );

void main() {
  testWidgets('previews the share card with a share button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(ReportShareCard), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('captures the on-screen card as non-empty PNG bytes',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final ShareReportSheetState state = tester.state(
      find.byType(ShareReportSheet),
    );

    final Uint8List? bytes = await tester.runAsync(state.captureCardPng);

    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
    // PNG magic bytes.
    expect(
      bytes.sublist(0, 4),
      <int>[0x89, 0x50, 0x4E, 0x47],
    );
  });
}
