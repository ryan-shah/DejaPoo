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
        Semantics(
          label: _summaryLabel(total),
          excludeSemantics: true,
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 48,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _Legend(distribution: distribution, brightness: brightness),
      ],
    );
  }

  /// Builds a screen-reader summary of the distribution, e.g.
  /// "Type distribution: Type 4 45%, Type 3 30%, Type 5 25%".
  String _summaryLabel(int total) {
    final List<MapEntry<BristolType, int>> sorted =
        distribution.entries.where((MapEntry<BristolType, int> e) => e.value > 0).toList()
          ..sort(
            (MapEntry<BristolType, int> a, MapEntry<BristolType, int> b) =>
                b.value.compareTo(a.value),
          );
    final String parts = sorted
        .map(
          (MapEntry<BristolType, int> e) =>
              'Type ${e.key.number} ${(e.value / total * 100).round()}%',
        )
        .join(', ');
    return 'Type distribution: $parts';
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
