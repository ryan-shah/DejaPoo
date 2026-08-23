import 'dart:ui' as ui;

import 'package:dejapoo/data/export/file_delivery.dart';
import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:dejapoo/features/reports/widgets/report_share_card.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Device-pixel multiplier used when rasterising the card. 3x keeps text
/// crisp when the PNG is viewed full-screen or on a high-density display.
const double _capturePixelRatio = 3;

/// A modal bottom sheet that previews the current report period as a share
/// card and rasterises it to a PNG on demand.
///
/// The card is captured from a live on-screen [RepaintBoundary] rather than
/// rendered off-screen: `RenderRepaintBoundary.toImage` rasterises its own
/// layer at its own logical size and ignores ancestor transforms, so the
/// [FittedBox] that scales the preview down to fit the sheet does not affect
/// the captured image.
class ShareReportSheet extends StatefulWidget {
  const ShareReportSheet({
    required this.rangeLabel,
    required this.firstDay,
    required this.lastDay,
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

  /// First inclusive day of the period (used in the file name).
  final DateTime firstDay;

  /// Last inclusive day of the period (used in the file name).
  final DateTime lastDay;

  /// Timestamp shown on the card.
  final DateTime generatedOn;

  /// Summary statistics for the period.
  final ReportStats stats;

  /// Count of logged events per Bristol type for the period.
  final Map<BristolType, int> distribution;

  /// Already-bucketed per-period counts for the bar chart.
  final List<PeriodTypeCount> buckets;

  /// X-axis labels, one per unique period start in [buckets].
  final List<String> periodLabels;

  /// Whether the card includes the per-period bar chart.
  final bool showBarChart;

  /// Opens this sheet as a modal bottom sheet over [context].
  static Future<void> show(
    BuildContext context, {
    required String rangeLabel,
    required DateTime firstDay,
    required DateTime lastDay,
    required DateTime generatedOn,
    required ReportStats stats,
    required Map<BristolType, int> distribution,
    required List<PeriodTypeCount> buckets,
    required List<String> periodLabels,
    bool showBarChart = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ShareReportSheet(
          rangeLabel: rangeLabel,
          firstDay: firstDay,
          lastDay: lastDay,
          generatedOn: generatedOn,
          stats: stats,
          distribution: distribution,
          buckets: buckets,
          periodLabels: periodLabels,
          showBarChart: showBarChart,
        ),
      ),
    );
  }

  @override
  State<ShareReportSheet> createState() => ShareReportSheetState();
}

/// State for [ShareReportSheet]. Public so tests can drive [captureCardPng]
/// directly instead of going through the platform share sheet.
class ShareReportSheetState extends State<ShareReportSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  /// Rasterises the on-screen card to PNG bytes.
  Future<Uint8List> captureCardPng() async {
    final RenderRepaintBoundary boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(
      pixelRatio: _capturePixelRatio,
    );
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        throw StateError('Could not encode the report image');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// File name for the exported image, e.g.
  /// `dejapoo_report_2026-07-01_2026-07-31.png`.
  String get _fileName =>
      'dejapoo_report_${_isoDate(widget.firstDay)}_'
      '${_isoDate(widget.lastDay)}.png';

  static String _isoDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final Uint8List bytes = await captureCardPng();
      await deliverFile(bytes, _fileName, 'image/png');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          Spacing.md,
          Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Share this period',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Flexible(
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: SizedBox(
                      width: reportShareCardWidth,
                      child: ReportShareCard(
                        rangeLabel: widget.rangeLabel,
                        generatedOn: widget.generatedOn,
                        stats: widget.stats,
                        distribution: widget.distribution,
                        buckets: widget.buckets,
                        periodLabels: widget.periodLabels,
                        showBarChart: widget.showBarChart,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _shareImage,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(kIsWeb ? Icons.download : Icons.ios_share),
              label: const Text(kIsWeb ? 'Download image' : 'Share image'),
            ),
          ],
        ),
      ),
    );
  }
}
