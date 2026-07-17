import 'package:dejapoo/features/home/providers/timeline_providers.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:flutter/material.dart';

/// A card summarising today's bowel movement count and Bristol type breakdown.
///
/// When [summary] has zero count, shows "No movements today".
class TodayHeader extends StatelessWidget {
  const TodayHeader({required this.summary, super.key});

  /// Today's summary data from [todaySummaryProvider].
  final TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              _countLabel(summary.count),
              style: theme.textTheme.headlineSmall,
            ),
            if (summary.byType.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: _buildTypeChips(summary.byType, colors),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _countLabel(int count) {
    if (count == 0) return 'No movements today';
    if (count == 1) return '1 movement today';
    return '$count movements today';
  }

  List<Widget> _buildTypeChips(
    Map<BristolType, int> byType,
    ColorScheme colors,
  ) {
    final List<MapEntry<BristolType, int>> sorted = byType.entries.toList()
      ..sort(
        (MapEntry<BristolType, int> a, MapEntry<BristolType, int> b) =>
            a.key.number.compareTo(b.key.number),
      );

    return sorted.map((MapEntry<BristolType, int> entry) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BristolIcon(type: entry.key, size: IconSizes.statTileIcon),
          const SizedBox(width: Spacing.xs),
          Text(
            '${entry.value}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }).toList();
  }
}
