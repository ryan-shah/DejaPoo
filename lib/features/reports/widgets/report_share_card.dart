import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/charts/stacked_type_bar_chart.dart';
import 'package:dejapoo/features/reports/widgets/charts/type_donut_chart.dart';
import 'package:dejapoo/features/reports/widgets/stat_tiles.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';

/// Logical width the share card is laid out at. Fixed so the rasterised PNG
/// has a predictable aspect ratio regardless of the device it was made on.
const double reportShareCardWidth = 360;

/// A shareable summary of one report period, rendered as a self-contained
/// card at a fixed [reportShareCardWidth].
///
/// Purely presentational: every value is passed in, nothing is read from a
/// provider, so it can be rasterised (see `ShareReportSheet`) or unit-tested
/// with plain fixtures. It paints an opaque background so the captured PNG is
/// never transparent.
class ReportShareCard extends StatelessWidget {
  const ReportShareCard({
    required this.rangeLabel,
    required this.generatedOn,
    required this.stats,
    required this.distribution,
    required this.buckets,
    required this.periodLabels,
    this.showBarChart = true,
    super.key,
  });

  /// Human-readable label for the period, e.g. "July 2026".
  final String rangeLabel;

  /// Timestamp shown in the "Generated on …" footnote of the header.
  final DateTime generatedOn;

  /// Summary statistics for the period.
  final ReportStats stats;

  /// Count of logged events per Bristol type for the period.
  final Map<BristolType, int> distribution;

  /// Already-bucketed per-period counts for the bar chart.
  final List<PeriodTypeCount> buckets;

  /// X-axis labels, one per unique period start in [buckets].
  final List<String> periodLabels;

  /// Whether to include the per-period bar chart. False for single-day
  /// ranges, where a one-bar chart carries no information.
  final bool showBarChart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Material(
      // Opaque so the rasterised PNG has a real background.
      color: colors.surface,
      child: SizedBox(
        width: reportShareCardWidth,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Header(
                rangeLabel: rangeLabel,
                generatedOn: generatedOn,
              ),
              const SizedBox(height: Spacing.md),
              StatTiles(stats: stats),
              if (showBarChart) ...<Widget>[
                const SizedBox(height: Spacing.lg),
                const _SectionTitle(title: 'Bristol type by period'),
                const SizedBox(height: Spacing.sm),
                StackedTypeBarChart(
                  buckets: buckets,
                  periodLabels: periodLabels,
                ),
              ],
              const SizedBox(height: Spacing.lg),
              const _SectionTitle(title: 'Bristol type distribution'),
              const SizedBox(height: Spacing.sm),
              TypeDonutChart(distribution: distribution),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.rangeLabel, required this.generatedOn});

  final String rangeLabel;
  final DateTime generatedOn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(
            Icons.insights,
            size: 20,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'DejaPoo',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                rangeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Generated on ${_formatDate(context, generatedOn)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats [date] with the ambient Material localizations when available,
  /// falling back to an ISO-8601 date so the card also renders outside a
  /// localized subtree.
  String _formatDate(BuildContext context, DateTime date) {
    final MaterialLocalizations? localizations =
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    if (localizations != null) {
      return localizations.formatMediumDate(date);
    }
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}
