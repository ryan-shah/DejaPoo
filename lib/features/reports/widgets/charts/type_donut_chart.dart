import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A donut chart showing the distribution of Bristol types.
///
/// Pure presentational widget: takes a pre-computed [distribution] map and
/// performs no data fetching.
class TypeDonutChart extends StatelessWidget {
  const TypeDonutChart({super.key, required this.distribution});

  /// Count of logged events per Bristol type.
  final Map<BristolType, int> distribution;

  @override
  Widget build(BuildContext context) {
    final int total =
        distribution.values.fold(0, (int sum, int count) => sum + count);

    if (total == 0) {
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

    final Brightness brightness = Theme.of(context).brightness;

    final List<PieChartSectionData> sections = <PieChartSectionData>[
      for (final BristolType type in BristolType.values)
        if ((distribution[type] ?? 0) > 0)
          PieChartSectionData(
            value: (distribution[type] ?? 0).toDouble(),
            color: BristolPalette.colorFor(type, brightness),
            title: '',
            radius: 40,
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _Legend(distribution: distribution, brightness: brightness),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.distribution, required this.brightness});

  final Map<BristolType, int> distribution;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: <Widget>[
        for (final BristolType type in BristolType.values)
          if ((distribution[type] ?? 0) > 0)
            Semantics(
              label: 'Type ${type.number}: ${type.label}, '
                  '${distribution[type]} logged',
              child: Chip(
                backgroundColor:
                    BristolPalette.colorFor(type, brightness).withValues(
                  alpha: 0.2,
                ),
                avatar: CircleAvatar(
                  backgroundColor: BristolPalette.colorFor(type, brightness),
                  radius: 6,
                ),
                label: Text('Type ${type.number}: ${distribution[type]}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
      ],
    );
  }
}
