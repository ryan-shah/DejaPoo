import 'dart:collection';

import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/providers/timeline_providers.dart';
import 'package:dejapoo/features/reports/providers/report_providers.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "List" tab of the reports screen: a row of multi-select Bristol
/// type filter chips above a reverse-chronological, day-grouped list of
/// entries within the currently selected [ReportRange].
class ReportsListTab extends ConsumerStatefulWidget {
  const ReportsListTab({super.key});

  @override
  ConsumerState<ReportsListTab> createState() => _ReportsListTabState();
}

class _ReportsListTabState extends ConsumerState<ReportsListTab> {
  /// The set of Bristol types currently included in the list. All types are
  /// selected by default (no filtering).
  Set<BristolType> _selectedTypes = BristolType.values.toSet();

  void _toggleType(BristolType type, bool selected) {
    setState(() {
      final Set<BristolType> next = Set<BristolType>.of(_selectedTypes);
      if (selected) {
        next.add(type);
      } else {
        next.remove(type);
      }
      _selectedTypes = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BowelMovement>> entriesAsync = ref.watch(
      reportEntriesProvider,
    );

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            Spacing.sm,
          ),
          child: _FilterChipsRow(
            selectedTypes: _selectedTypes,
            onToggle: _toggleType,
          ),
        ),
        Expanded(
          child: entriesAsync.when(
            data: (List<BowelMovement> entries) {
              final List<BowelMovement> filtered = entries
                  .where(
                    (BowelMovement e) => _selectedTypes.contains(
                      e.bristolType,
                    ),
                  )
                  .toList();
              return _EntryListSection(
                allEntries: entries,
                filteredEntries: filtered,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Text('Something went wrong: $error'),
            ),
          ),
        ),
      ],
    );
  }
}

/// The row of Bristol type filter chips.
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.selectedTypes,
    required this.onToggle,
  });

  final Set<BristolType> selectedTypes;
  final void Function(BristolType type, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: <Widget>[
        for (final BristolType type in BristolType.values)
          FilterChip(
            label: Text('Type ${type.number}'),
            avatar: CircleAvatar(
              backgroundColor: BristolPalette.colorFor(type, brightness),
            ),
            selected: selectedTypes.contains(type),
            onSelected: (bool selected) => onToggle(type, selected),
          ),
      ],
    );
  }
}

/// Shows the "Showing N of M entries" count label, the day-grouped entry
/// list, or the empty state.
class _EntryListSection extends StatelessWidget {
  const _EntryListSection({
    required this.allEntries,
    required this.filteredEntries,
  });

  final List<BowelMovement> allEntries;
  final List<BowelMovement> filteredEntries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String countLabel = filteredEntries.length == allEntries.length
        ? '${allEntries.length} '
              '${allEntries.length == 1 ? 'entry' : 'entries'}'
        : 'Showing ${filteredEntries.length} of ${allEntries.length} entries';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          child: Text(
            countLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: filteredEntries.isEmpty
              ? const _EmptyState()
              : _GroupedEntryList(entries: filteredEntries),
        ),
      ],
    );
  }
}

/// Centered "No entries" message shown when no entries match the current
/// range and filter selection.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'No entries',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// The scrollable, day-grouped list of entries.
class _GroupedEntryList extends StatelessWidget {
  const _GroupedEntryList({required this.entries});

  final List<BowelMovement> entries;

  @override
  Widget build(BuildContext context) {
    final LinkedHashMap<DateTime, List<BowelMovement>> grouped =
        groupEntriesByDay(entries);

    final List<Widget> children = <Widget>[];
    for (final MapEntry<DateTime, List<BowelMovement>> group
        in grouped.entries) {
      children.add(_DaySectionHeader(date: group.key));
      for (final BowelMovement entry in group.value) {
        children.add(_ReportEntryTile(entry: entry));
      }
    }
    children.add(const SizedBox(height: Spacing.lg));

    return ListView(children: children);
  }
}

/// A section header showing a formatted date for a group of entries.
class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.date});

  /// The midnight [DateTime] representing this day (local time).
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: Spacing.md,
        right: Spacing.md,
        top: Spacing.md,
        bottom: Spacing.xs,
      ),
      child: Text(
        _formatDayHeader(date),
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Formats a date as "Today", "Yesterday", or "Jul 15, 2026".
  String _formatDayHeader(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// A read-only tile displaying a single [BowelMovement] in the reports list:
/// Bristol icon, time (or "All day"), type label, detail badges, and a note
/// preview. Unlike the home timeline's `TimelineEntryTile`, this has no tap
/// or swipe actions.
class _ReportEntryTile extends StatelessWidget {
  const _ReportEntryTile({required this.entry});

  final BowelMovement entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
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
                Text(
                  _formatTime(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Type ${entry.bristolType.number} — '
                  '${entry.bristolType.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasDetails) ...<Widget>[
                  const SizedBox(height: Spacing.xs),
                  Wrap(
                    spacing: Spacing.xs,
                    runSpacing: Spacing.xs,
                    children: _buildBadges(colors),
                  ),
                ],
                if (entry.note != null && entry.note!.isNotEmpty) ...<Widget>[
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
      badges.add(_Badge(label: 'Urgency ${entry.urgency}', colors: colors));
    }
    if (entry.strain != null) {
      badges.add(_Badge(label: 'Strain ${entry.strain}', colors: colors));
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
