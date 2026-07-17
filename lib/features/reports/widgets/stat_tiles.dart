import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';

/// A row of small stat cards summarising a [ReportStats] snapshot.
class StatTiles extends StatelessWidget {
  const StatTiles({required this.stats, super.key});

  /// Summary statistics for the currently selected report range.
  final ReportStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        _StatTile(
          icon: Icons.numbers,
          label: 'Total',
          value: '${stats.total}',
        ),
        _StatTile(
          icon: Icons.trending_up,
          label: 'Avg/day',
          value: stats.averagePerDay.toStringAsFixed(1),
        ),
        _StatTile(
          icon: Icons.star,
          label: 'Most common',
          value: stats.mostCommonType?.label ?? '—',
        ),
        _StatTile(
          icon: Icons.favorite,
          label: 'Healthy (3-5)',
          value: '${stats.healthyPercentage.toStringAsFixed(0)}%',
        ),
        _StatTile(
          icon: Icons.timer,
          label: 'Longest gap',
          value: '${stats.longestGapDays}d',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Semantics(
      label: '$label: $value',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: IconSizes.statTileIcon,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
