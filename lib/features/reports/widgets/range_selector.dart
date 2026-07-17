import 'package:dejapoo/domain/report_range.dart';
import 'package:dejapoo/features/reports/providers/report_providers.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bar with a period-kind selector, prev/next navigation, and the current
/// period's label. Lives at the top of the reports screen.
class RangeSelector extends ConsumerWidget {
  const RangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportRange range = ref.watch(selectedReportRangeProvider);
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ReportRangeKind>(
              segments: const <ButtonSegment<ReportRangeKind>>[
                ButtonSegment<ReportRangeKind>(
                  value: ReportRangeKind.day,
                  label: Text('Day'),
                ),
                ButtonSegment<ReportRangeKind>(
                  value: ReportRangeKind.week,
                  label: Text('Week'),
                ),
                ButtonSegment<ReportRangeKind>(
                  value: ReportRangeKind.month,
                  label: Text('Month'),
                ),
                ButtonSegment<ReportRangeKind>(
                  value: ReportRangeKind.year,
                  label: Text('Year'),
                ),
                ButtonSegment<ReportRangeKind>(
                  value: ReportRangeKind.custom,
                  label: Text('Custom'),
                ),
              ],
              selected: <ReportRangeKind>{range.kind},
              onSelectionChanged: (Set<ReportRangeKind> selection) {
                final ReportRangeKind kind = selection.first;
                if (kind == range.kind) {
                  return;
                }
                if (kind == ReportRangeKind.custom) {
                  _openCustomPicker(context, ref, range);
                  return;
                }
                ref
                    .read(selectedReportRangeProvider.notifier)
                    .setRange(_rangeForKind(kind, DateTime.now()));
              },
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous period',
                onPressed: () {
                  ref.read(selectedReportRangeProvider.notifier).previous();
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    range.displayLabel(localizations),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next period',
                onPressed: () {
                  ref.read(selectedReportRangeProvider.notifier).next();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  ReportRange _rangeForKind(ReportRangeKind kind, DateTime anchor) {
    switch (kind) {
      case ReportRangeKind.day:
        return ReportRange.day(anchor: anchor);
      case ReportRangeKind.week:
        return ReportRange.week(anchor: anchor);
      case ReportRangeKind.month:
        return ReportRange.month(anchor: anchor);
      case ReportRangeKind.year:
        return ReportRange.year(anchor: anchor);
      case ReportRangeKind.custom:
        return ReportRange.custom(from: anchor, to: anchor);
    }
  }

  Future<void> _openCustomPicker(
    BuildContext context,
    WidgetRef ref,
    ReportRange range,
  ) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: range.firstDay,
        end: range.lastDay,
      ),
    );
    if (picked == null) {
      return;
    }
    ref
        .read(selectedReportRangeProvider.notifier)
        .setRange(ReportRange.custom(from: picked.start, to: picked.end));
  }
}
