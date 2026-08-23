import 'package:flutter/material.dart';

/// The kind of period a [ReportRange] represents.
enum ReportRangeKind { day, last7Days, month, year, custom }

/// The currently selected time range for the reports screen.
///
/// Day/7-day/Month/Year ranges are anchored to a date-only [DateTime] and
/// derive their [firstDay]/[lastDay] from it; Custom ranges are given an
/// explicit [firstDay]/[lastDay] pair (e.g. from a date picker).
///
/// [firstDay] and [lastDay] are always date-only (midnight, local) and both
/// inclusive.
@immutable
class ReportRange {
  const ReportRange._({
    required this.kind,
    required this.firstDay,
    required this.lastDay,
    required this.anchor,
  });

  /// A single calendar day containing [anchor].
  factory ReportRange.day({required DateTime anchor}) {
    final DateTime day = _dateOnly(anchor);
    return ReportRange._(
      kind: ReportRangeKind.day,
      firstDay: day,
      lastDay: day,
      anchor: day,
    );
  }

  /// The trailing 7-day window **ending on** [anchor] (inclusive), i.e.
  /// `anchor - 6 days` through `anchor`. With the default anchor of today
  /// this is "the last 7 days", which is what users mean by "this week".
  ///
  /// NOTE — anchor semantics are inverted here: for every other kind
  /// [anchor] is the FIRST day of the period, but for a 7-day window it is
  /// the LAST day. The window deliberately does not snap to an ISO calendar
  /// week; `weekStart()` in `aggregates.dart` remains a chart-bucketing
  /// helper only and is deliberately not used here.
  factory ReportRange.last7Days({required DateTime anchor}) {
    final DateTime a = _dateOnly(anchor);
    final DateTime start = DateTime(a.year, a.month, a.day - 6);
    return ReportRange._(
      kind: ReportRangeKind.last7Days,
      firstDay: start,
      lastDay: a,
      anchor: a,
    );
  }

  /// The calendar month containing [anchor].
  factory ReportRange.month({required DateTime anchor}) {
    final DateTime a = _dateOnly(anchor);
    final DateTime start = DateTime(a.year, a.month);
    final DateTime end = DateTime(a.year, a.month + 1, 0);
    return ReportRange._(
      kind: ReportRangeKind.month,
      firstDay: start,
      lastDay: end,
      anchor: start,
    );
  }

  /// The calendar year containing [anchor].
  factory ReportRange.year({required DateTime anchor}) {
    final DateTime a = _dateOnly(anchor);
    final DateTime start = DateTime(a.year);
    final DateTime end = DateTime(a.year, 12, 31);
    return ReportRange._(
      kind: ReportRangeKind.year,
      firstDay: start,
      lastDay: end,
      anchor: start,
    );
  }

  /// An arbitrary inclusive date range from [from] to [to].
  factory ReportRange.custom({required DateTime from, required DateTime to}) {
    final DateTime start = _dateOnly(from);
    final DateTime end = _dateOnly(to);
    return ReportRange._(
      kind: ReportRangeKind.custom,
      firstDay: start.isAfter(end) ? end : start,
      lastDay: start.isAfter(end) ? start : end,
      anchor: start.isAfter(end) ? end : start,
    );
  }

  /// Which kind of period this range represents.
  final ReportRangeKind kind;

  /// First inclusive calendar day of the range (date-only, local).
  final DateTime firstDay;

  /// Last inclusive calendar day of the range (date-only, local).
  final DateTime lastDay;

  /// The date-only anchor this range was built from.
  ///
  /// This is the START of the period for Day/Month/Year (and [firstDay] for
  /// Custom), but the **END** of the window for
  /// [ReportRangeKind.last7Days] — a trailing 7-day window is identified by
  /// the day it ends on. Anything stepping or comparing anchors must respect
  /// that inversion.
  final DateTime anchor;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Steps this range forward by one period. Custom ranges step forward by
  /// their own length (kept adjacent, non-overlapping).
  ReportRange next() {
    switch (kind) {
      case ReportRangeKind.day:
        return ReportRange.day(
          anchor: DateTime(anchor.year, anchor.month, anchor.day + 1),
        );
      case ReportRangeKind.last7Days:
        return ReportRange.last7Days(
          anchor: DateTime(anchor.year, anchor.month, anchor.day + 7),
        );
      case ReportRangeKind.month:
        return ReportRange.month(
          anchor: DateTime(anchor.year, anchor.month + 1),
        );
      case ReportRangeKind.year:
        return ReportRange.year(anchor: DateTime(anchor.year + 1));
      case ReportRangeKind.custom:
        final int lengthDays = lastDay.difference(firstDay).inDays + 1;
        final DateTime newFrom = DateTime(
          firstDay.year,
          firstDay.month,
          firstDay.day + lengthDays,
        );
        final DateTime newTo = DateTime(
          lastDay.year,
          lastDay.month,
          lastDay.day + lengthDays,
        );
        return ReportRange.custom(from: newFrom, to: newTo);
    }
  }

  /// Steps this range backward by one period. Custom ranges step backward by
  /// their own length (kept adjacent, non-overlapping).
  ReportRange previous() {
    switch (kind) {
      case ReportRangeKind.day:
        return ReportRange.day(
          anchor: DateTime(anchor.year, anchor.month, anchor.day - 1),
        );
      case ReportRangeKind.last7Days:
        return ReportRange.last7Days(
          anchor: DateTime(anchor.year, anchor.month, anchor.day - 7),
        );
      case ReportRangeKind.month:
        return ReportRange.month(
          anchor: DateTime(anchor.year, anchor.month - 1),
        );
      case ReportRangeKind.year:
        return ReportRange.year(anchor: DateTime(anchor.year - 1));
      case ReportRangeKind.custom:
        final int lengthDays = lastDay.difference(firstDay).inDays + 1;
        final DateTime newFrom = DateTime(
          firstDay.year,
          firstDay.month,
          firstDay.day - lengthDays,
        );
        final DateTime newTo = DateTime(
          lastDay.year,
          lastDay.month,
          lastDay.day - lengthDays,
        );
        return ReportRange.custom(from: newFrom, to: newTo);
    }
  }

  /// A human-readable label for this range, e.g. "July 2026",
  /// "7/13/2026 – 7/19/2026", "2026".
  String displayLabel(MaterialLocalizations localizations) {
    switch (kind) {
      case ReportRangeKind.day:
        return localizations.formatMediumDate(firstDay);
      case ReportRangeKind.last7Days:
      case ReportRangeKind.custom:
        return '${localizations.formatShortDate(firstDay)} – '
            '${localizations.formatShortDate(lastDay)}';
      case ReportRangeKind.month:
        return localizations.formatMonthYear(firstDay);
      case ReportRangeKind.year:
        return '${firstDay.year}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange &&
      other.kind == kind &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(kind, firstDay, lastDay);

  @override
  String toString() => 'ReportRange($kind, $firstDay - $lastDay)';
}
