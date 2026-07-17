import 'dart:async';
import 'dart:collection';

import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/providers/timeline_providers.dart';
import 'package:dejapoo/features/home/widgets/entry_sheet.dart';
import 'package:dejapoo/features/home/widgets/quick_log_popup.dart';
import 'package:dejapoo/features/home/widgets/timeline_entry_tile.dart';
import 'package:dejapoo/features/home/widgets/today_header.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's home screen showing a today-at-a-glance header and a
/// reverse-chronological timeline of bowel movements grouped by day.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BowelMovement>> timelineAsync =
        ref.watch(timelineProvider);
    final TodaySummary summary = ref.watch(todaySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DejaPoo')),
      body: timelineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: Text('Something went wrong: $error'),
        ),
        data: (List<BowelMovement> entries) {
          if (entries.isEmpty) {
            return _EmptyState(summary: summary);
          }
          return _TimelineList(entries: entries, summary: summary);
        },
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _quickLog(context, ref),
        child: FloatingActionButton(
          onPressed: () => showEntrySheet(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// Handles the FAB long-press: shows the quick-log popup, saves the entry,
/// and shows a confirmation SnackBar.
Future<void> _quickLog(BuildContext context, WidgetRef ref) async {
  final BristolType? type = await showQuickLogPopup(context);
  if (type == null || !context.mounted) return;

  final BowelMovementRepository repo =
      ref.read(bowelMovementRepositoryProvider);
  await repo.create(occurredAt: DateTime.now(), bristolType: type);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Type ${type.number} logged')),
    );
}

/// Shown when there are no entries in the last 30 days.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.summary});

  final TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return ListView(
      children: <Widget>[
        TodayHeader(summary: summary),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.spa_outlined,
                  size: 64,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'No entries yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Tap + to log your first movement',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The scrollable timeline with the today header, day section headers,
/// and entry tiles with swipe-to-edit and swipe-to-delete gestures.
class _TimelineList extends ConsumerWidget {
  const _TimelineList({required this.entries, required this.summary});

  final List<BowelMovement> entries;
  final TodaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LinkedHashMap<DateTime, List<BowelMovement>> grouped =
        groupEntriesByDay(entries);

    // Build a flat list of widgets: header card, then alternating section
    // headers and entry tiles.
    final List<Widget> slivers = <Widget>[
      TodayHeader(summary: summary),
      const SizedBox(height: Spacing.sm),
    ];

    for (final MapEntry<DateTime, List<BowelMovement>> group
        in grouped.entries) {
      slivers.add(_DaySectionHeader(date: group.key));
      for (final BowelMovement entry in group.value) {
        slivers.add(
          _DismissibleEntryTile(entry: entry, ref: ref),
        );
      }
    }

    // Bottom padding so the FAB doesn't obscure the last entry.
    slivers.add(const SizedBox(height: 80));

    return ListView(children: slivers);
  }
}

/// A [TimelineEntryTile] wrapped in a [Dismissible] that supports
/// swipe-right to edit and swipe-left to delete with undo.
class _DismissibleEntryTile extends StatelessWidget {
  const _DismissibleEntryTile({
    required this.entry,
    required this.ref,
  });

  final BowelMovement entry;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey<String>(entry.id),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: Spacing.md),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.md),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: open the edit sheet, don't dismiss the tile.
          unawaited(showEntrySheet(context, existing: entry));
          return false;
        }
        // Swipe left: allow dismiss for deletion.
        return true;
      },
      onDismissed: (DismissDirection direction) {
        // Capture the full entity before deletion for undo.
        final BowelMovement deletedEntry = entry;
        final BowelMovementRepository repo =
            ref.read(bowelMovementRepositoryProvider);
        repo.softDelete(entry.id);

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Entry deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  repo.update(deletedEntry);
                },
              ),
            ),
          );
      },
      child: TimelineEntryTile(
        entry: entry,
        onTap: () => showEntrySheet(context, existing: entry),
      ),
    );
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
