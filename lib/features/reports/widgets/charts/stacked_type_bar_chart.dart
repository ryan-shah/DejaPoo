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
              width: 18,
              borderRadius: BorderRadius.circular(Radii.sm / 2),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
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
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= periodLabels.length) {
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
        const SizedBox(height: Spacing.md),
        _Legend(brightness: brightness),
      ],
    );
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
