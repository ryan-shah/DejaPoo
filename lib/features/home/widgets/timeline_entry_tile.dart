import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:flutter/material.dart';

/// A list tile displaying a single [BowelMovement] entry in the timeline.
///
/// Shows the Bristol type icon, time of day (or "All day" for [dateOnly]
/// entries), Bristol type label, optional detail badges, and a note preview.
class TimelineEntryTile extends StatelessWidget {
  const TimelineEntryTile({
    required this.entry,
    this.onTap,
    super.key,
  });

  /// The bowel movement to display.
  final BowelMovement entry;

  /// Called when the tile is tapped (typically opens the edit sheet).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BristolIcon(type: entry.bristolType, size: IconSizes.bristolIcon),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Time and Bristol type label
                  Row(
                    children: <Widget>[
                      Text(
                        _formatTime(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Type ${entry.bristolType.number} — '
                    '${entry.bristolType.label}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Detail badges
                  if (_hasDetails) ...<Widget>[
                    const SizedBox(height: Spacing.xs),
                    Wrap(
                      spacing: Spacing.xs,
                      runSpacing: Spacing.xs,
                      children: _buildBadges(colors),
                    ),
                  ],
                  // Note preview
                  if (entry.note != null &&
                      entry.note!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      _firstLine(entry.note!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context) {
    if (entry.dateOnly) return 'All day';
    final TimeOfDay time = TimeOfDay(
      hour: entry.occurredAt.hour,
      minute: entry.occurredAt.minute,
    );
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  bool get _hasDetails =>
      entry.size != null ||
      entry.color != null ||
      entry.urgency != null ||
      entry.strain != null ||
      entry.blood == true;

  List<Widget> _buildBadges(ColorScheme colors) {
    final List<Widget> badges = <Widget>[];

    if (entry.size != null) {
      badges.add(_Badge(label: entry.size!.label, colors: colors));
    }
    if (entry.color != null) {
      badges.add(_Badge(label: entry.color!.label, colors: colors));
    }
    if (entry.urgency != null) {
      badges.add(
        _Badge(label: 'Urgency ${entry.urgency}', colors: colors),
      );
    }
    if (entry.strain != null) {
      badges.add(
        _Badge(label: 'Strain ${entry.strain}', colors: colors),
      );
    }
    if (entry.blood == true) {
      badges.add(_Badge(label: 'Blood', colors: colors));
    }

    return badges;
  }

  String _firstLine(String text) {
    final int newline = text.indexOf('\n');
    if (newline == -1) return text;
    return text.substring(0, newline);
  }
}

/// A small chip-like badge for displaying optional entry details.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colors});

  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
      ),
    );
  }
}
