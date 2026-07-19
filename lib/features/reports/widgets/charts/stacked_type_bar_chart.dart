import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A stacked bar chart showing Bristol type counts per period.
///
/// Pure presentational widget: it takes already-bucketed [buckets] (one
/// [PeriodTypeCount] per period/type combination) and a parallel list of
/// [periodLabels] for the x-axis. It performs no data fetching.
class StackedTypeBarChart extends StatelessWidget {
  const StackedTypeBarChart({
    super.key,
    required this.buckets,
    required this.periodLabels,
  });

  /// The rolled-up counts to render, grouped internally by period start.
  final List<PeriodTypeCount> buckets;

  /// Labels for the x-axis, one per unique period start (in chronological
  /// order matching the sorted period starts found in [buckets]).
  final List<String> periodLabels;

  static double _barWidth(int barCount) {
    if (barCount <= 7) return 18;
    if (barCount <= 14) return 12;
    if (barCount <= 31) return 8;
    return 4;
  }

  static int _labelInterval(int barCount) {
    if (barCount <= 10) return 1;
    if (barCount <= 20) return 2;
    if (barCount <= 40) return 5;
    if (barCount <= 60) return 10;
    return (barCount / 6).ceil();
  }

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const _NoDataMessage();
    }

    final Brightness brightness = Theme.of(context).brightness;

    final List<DateTime> periodStarts =
        <DateTime>{for (final PeriodTypeCount b in buckets) b.periodStart}
            .toList()
          ..sort();

    final Map<DateTime, Map<BristolType, int>> grouped =
        <DateTime, Map<BristolType, int>>{
      for (final DateTime p in periodStarts) p: <BristolType, int>{},
    };
    for (final PeriodTypeCount b in buckets) {
      grouped[b.periodStart]![b.type] = b.count;
    }

    double maxY = 0;
    final List<BarChartGroupData> barGroups = <BarChartGroupData>[];
    for (int i = 0; i < periodStarts.length; i++) {
      final Map<BristolType, int> counts = grouped[periodStarts[i]]!;
      double cumulative = 0;
      final List<BarChartRodStackItem> stackItems = <BarChartRodStackItem>[];
      for (final BristolType type in BristolType.values) {
        final int count = counts[type] ?? 0;
        if (count == 0) {
          continue;
        }
        final double from = cumulative;
        final double to = cumulative + count;
        stackItems.add(
          BarChartRodStackItem(
            from,
            to,
            BristolPalette.colorFor(type, brightness),
          ),
        );
        cumulative = to;
      }
      if (cumulative > maxY) {
        maxY = cumulative;
      }
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: cumulative,
              rodStackItems: stackItems,
              width: _barWidth(periodStarts.length),
              borderRadius: BorderRadius.circular(Radii.sm / 2),
            ),
          ],
        ),
      );
    }

    final int labelInterval = _labelInterval(periodStarts.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: _summaryLabel(grouped, periodStarts.length),
          excludeSemantics: true,
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.1,
              barGroups: barGroups,
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= periodLabels.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % labelInterval != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Text(
                          periodLabels[index],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
        const SizedBox(height: Spacing.md),
        _Legend(brightness: brightness),
      ],
    );
  }

  /// Builds a screen-reader summary of type totals across all periods, e.g.
  /// "Type totals across 30 periods: Type 4 12, Type 3 8".
  String _summaryLabel(
    Map<DateTime, Map<BristolType, int>> grouped,
    int periodCount,
  ) {
    final Map<BristolType, int> totals = <BristolType, int>{};
    for (final Map<BristolType, int> counts in grouped.values) {
      for (final MapEntry<BristolType, int> entry in counts.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final List<MapEntry<BristolType, int>> sorted =
        totals.entries.where((MapEntry<BristolType, int> e) => e.value > 0).toList()
          ..sort(
            (MapEntry<BristolType, int> a, MapEntry<BristolType, int> b) =>
                b.value.compareTo(a.value),
          );
    final String parts = sorted
        .map((MapEntry<BristolType, int> e) => 'Type ${e.key.number} ${e.value}')
        .join(', ');
    return 'Type totals across $periodCount periods: $parts';
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: <Widget>[
        for (final BristolType type in BristolType.values)
          Semantics(
            label: 'Type ${type.number}: ${type.label}',
            child: Chip(
              backgroundColor:
                  BristolPalette.colorFor(type, brightness).withValues(
                alpha: 0.2,
              ),
              avatar: CircleAvatar(
                backgroundColor: BristolPalette.colorFor(type, brightness),
                radius: 6,
              ),
              label: Text('Type ${type.number}'),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

class _NoDataMessage extends StatelessWidget {
  const _NoDataMessage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          'No data',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
