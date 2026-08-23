import 'dart:async';

import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:dejapoo/features/reports/providers/report_providers.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/charts/stacked_type_bar_chart.dart';
import 'package:dejapoo/features/reports/widgets/charts/type_donut_chart.dart';
import 'package:dejapoo/features/reports/widgets/range_selector.dart';
import 'package:dejapoo/features/reports/widgets/reports_list_tab.dart';
import 'package:dejapoo/features/reports/widgets/share_report_sheet.dart';
import 'package:dejapoo/features/reports/widgets/stat_tiles.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:dejapoo/ui/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A span of days above which the bar chart rolls up by month instead of
/// showing one bar per day (keeps the x-axis readable).
const int _maxDayBucketSpan = 62;

/// Chart-ready per-period counts plus their matching x-axis labels.
typedef _BucketedCounts = ({List<PeriodTypeCount> buckets, List<String> labels});

/// Whether [range] is long enough that the bar chart should roll up by month
/// instead of showing one bar per day.
bool _useMonthBars(ReportRange range) {
  if (range.kind == ReportRangeKind.year) {
    return true;
  }
  if (range.kind == ReportRangeKind.custom) {
    final int spanDays = range.lastDay.difference(range.firstDay).inDays + 1;
    return spanDays > _maxDayBucketSpan;
  }
  return false;
}

/// Buckets [dailyCounts] the way the on-screen chart does for [range] — by
/// day for short ranges, by month for long ones — and builds the matching
/// x-axis labels. Shared by the summary tab and the share card so both always
/// show the same chart.
_BucketedCounts _bucketCountsForRange(
  ReportRange range,
  List<DailyTypeCount> dailyCounts,
) {
  if (_useMonthBars(range)) {
    final List<PeriodTypeCount> monthly = rollUpByMonth(dailyCounts);
    return (buckets: monthly, labels: _monthLabels(monthly));
  }
  final List<PeriodTypeCount> daily = <PeriodTypeCount>[
    for (final DailyTypeCount d in dailyCounts)
      PeriodTypeCount(periodStart: d.day, type: d.type, count: d.count),
  ];
  return (buckets: daily, labels: _dayLabels(daily));
}

List<DateTime> _sortedPeriodStarts(List<PeriodTypeCount> buckets) =>
    <DateTime>{for (final PeriodTypeCount b in buckets) b.periodStart}.toList()
      ..sort();

List<String> _dayLabels(List<PeriodTypeCount> buckets) => <String>[
      for (final DateTime day in _sortedPeriodStarts(buckets))
        '${day.month}/${day.day}',
    ];

List<String> _monthLabels(List<PeriodTypeCount> buckets) => <String>[
      for (final DateTime month in _sortedPeriodStarts(buckets))
        '${month.month}/${month.year % 100}',
    ];

/// Top-level reports screen: a range selector, a Summary/List tab bar, and
/// the corresponding tab content.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: const <Widget>[_ShareAction()],
        ),
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
          error: (Object error, StackTrace stackTrace) => ErrorRetryWidget(
            error: error,
            onRetry: () => ref.invalidate(reportStatsProvider),
          ),
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
          error: (Object error, StackTrace stackTrace) => ErrorRetryWidget(
            error: error,
            onRetry: () => ref.invalidate(reportTypeDistributionProvider),
          ),
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
        final _BucketedCounts bucketed = _bucketCountsForRange(
          range,
          dailyCounts,
        );
        return StackedTypeBarChart(
          buckets: bucketed.buckets,
          periodLabels: bucketed.labels,
        );
      },
      loading: () => const _CenteredLoading(),
      error: (Object error, StackTrace stackTrace) => ErrorRetryWidget(
        error: error,
        onRetry: () => ref.invalidate(reportDailyTypeCountsProvider),
      ),
    );
  }
}

/// AppBar action that opens the share-as-image sheet for the selected period.
///
/// Disabled until every provider the share card needs has data, so the card
/// can never be built from a half-loaded (or errored) snapshot.
class _ShareAction extends ConsumerWidget {
  const _ShareAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportRange range = ref.watch(selectedReportRangeProvider);
    final AsyncValue<ReportStats> statsAsync = ref.watch(reportStatsProvider);
    final AsyncValue<Map<BristolType, int>> distributionAsync = ref.watch(
      reportTypeDistributionProvider,
    );
    final AsyncValue<List<DailyTypeCount>> dailyCountsAsync = ref.watch(
      reportDailyTypeCountsProvider,
    );

    final bool loadingOrError = statsAsync.isLoading ||
        statsAsync.hasError ||
        distributionAsync.isLoading ||
        distributionAsync.hasError ||
        dailyCountsAsync.isLoading ||
        dailyCountsAsync.hasError;

    final ReportStats? stats = statsAsync.value;
    final Map<BristolType, int>? distribution = distributionAsync.value;
    final List<DailyTypeCount>? dailyCounts = dailyCountsAsync.value;
    final bool ready = !loadingOrError &&
        stats != null &&
        distribution != null &&
        dailyCounts != null;

    return IconButton(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Share this period as an image',
      onPressed: !ready
          ? null
          : () {
              final _BucketedCounts bucketed = _bucketCountsForRange(
                range,
                dailyCounts,
              );
              unawaited(
                ShareReportSheet.show(
                  context,
                  rangeLabel: range.displayLabel(
                    MaterialLocalizations.of(context),
                  ),
                  firstDay: range.firstDay,
                  lastDay: range.lastDay,
                  generatedOn: DateTime.now(),
                  stats: stats,
                  distribution: distribution,
                  buckets: bucketed.buckets,
                  periodLabels: bucketed.labels,
                  showBarChart: range.kind != ReportRangeKind.day,
                ),
              );
            },
    );
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
