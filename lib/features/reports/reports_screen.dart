import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:dejapoo/features/reports/providers/report_providers.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/charts/stacked_type_bar_chart.dart';
import 'package:dejapoo/features/reports/widgets/charts/type_donut_chart.dart';
import 'package:dejapoo/features/reports/widgets/range_selector.dart';
import 'package:dejapoo/features/reports/widgets/reports_list_tab.dart';
import 'package:dejapoo/features/reports/widgets/stat_tiles.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A span of days above which the bar chart rolls up by month instead of
/// showing one bar per day (keeps the x-axis readable).
const int _maxDayBucketSpan = 62;

/// Top-level reports screen: a range selector, a Summary/List tab bar, and
/// the corresponding tab content.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Column(
          children: <Widget>[
            RangeSelector(),
            TabBar(
              tabs: <Widget>[
                Tab(text: 'Summary'),
                Tab(text: 'List'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _SummaryTab(),
                  ReportsListTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportRange range = ref.watch(selectedReportRangeProvider);
    final AsyncValue<ReportStats> statsAsync = ref.watch(
      reportStatsProvider,
    );
    final AsyncValue<Map<BristolType, int>> distributionAsync = ref.watch(
      reportTypeDistributionProvider,
    );

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: <Widget>[
        statsAsync.when(
          data: (ReportStats stats) => StatTiles(stats: stats),
          loading: () => const _CenteredLoading(),
          error: (Object error, StackTrace stackTrace) =>
              _ErrorMessage(error: error),
        ),
        const SizedBox(height: Spacing.lg),
        if (range.kind != ReportRangeKind.day) ...<Widget>[
          Text(
            'Bristol type by period',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.sm),
          _BarChartSection(range: range),
          const SizedBox(height: Spacing.lg),
        ],
        Text(
          'Bristol type distribution',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Spacing.sm),
        distributionAsync.when(
          data: (Map<BristolType, int> distribution) =>
              TypeDonutChart(distribution: distribution),
          loading: () => const _CenteredLoading(),
          error: (Object error, StackTrace stackTrace) =>
              _ErrorMessage(error: error),
        ),
      ],
    );
  }
}

/// Decides between day-level and month-level bars based on the selected
/// [range]'s kind (and, for custom ranges, its span) and renders the chart.
class _BarChartSection extends ConsumerWidget {
  const _BarChartSection({required this.range});

  final ReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DailyTypeCount>> dailyCountsAsync = ref.watch(
      reportDailyTypeCountsProvider,
    );

    return dailyCountsAsync.when(
      data: (List<DailyTypeCount> dailyCounts) {
        final bool useMonthBars = _useMonthBars(range);
        if (useMonthBars) {
          final List<PeriodTypeCount> monthly = rollUpByMonth(dailyCounts);
          return StackedTypeBarChart(
            buckets: monthly,
            periodLabels: _monthLabels(monthly),
          );
        }
        final List<PeriodTypeCount> daily = _toPeriodTypeCounts(dailyCounts);
        return StackedTypeBarChart(
          buckets: daily,
          periodLabels: _dayLabels(daily),
        );
      },
      loading: () => const _CenteredLoading(),
      error: (Object error, StackTrace stackTrace) =>
          _ErrorMessage(error: error),
    );
  }

  bool _useMonthBars(ReportRange range) {
    if (range.kind == ReportRangeKind.year) {
      return true;
    }
    if (range.kind == ReportRangeKind.custom) {
      final int spanDays =
          range.lastDay.difference(range.firstDay).inDays + 1;
      return spanDays > _maxDayBucketSpan;
    }
    return false;
  }

  List<PeriodTypeCount> _toPeriodTypeCounts(List<DailyTypeCount> daily) {
    return <PeriodTypeCount>[
      for (final DailyTypeCount d in daily)
        PeriodTypeCount(periodStart: d.day, type: d.type, count: d.count),
    ];
  }

  List<String> _dayLabels(List<PeriodTypeCount> buckets) {
    final List<DateTime> periodStarts =
        <DateTime>{for (final PeriodTypeCount b in buckets) b.periodStart}
            .toList()
          ..sort();
    return <String>[
      for (final DateTime day in periodStarts) '${day.month}/${day.day}',
    ];
  }

  List<String> _monthLabels(List<PeriodTypeCount> buckets) {
    final List<DateTime> periodStarts =
        <DateTime>{for (final PeriodTypeCount b in buckets) b.periodStart}
            .toList()
          ..sort();
    return <String>[
      for (final DateTime month in periodStarts)
        '${month.month}/${month.year % 100}',
    ];
  }
}

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Center(
        child: Text(
          'Something went wrong: $error',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
