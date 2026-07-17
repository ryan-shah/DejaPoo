import 'package:dejapoo/domain/aggregates.dart';
import 'package:flutter/material.dart';

/// The kind of period a [ReportRange] represents.
enum ReportRangeKind { day, week, month, year, custom }

/// The currently selected time range for the reports screen.
///
/// Day/Week/Month/Year ranges are anchored to a date-only [DateTime] and
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

  /// The Monday-Sunday ISO week containing [anchor].
  factory ReportRange.week({required DateTime anchor}) {
    final DateTime start = weekStart(_dateOnly(anchor));
    final DateTime end = DateTime(start.year, start.month, start.day + 6);
    return ReportRange._(
      kind: ReportRangeKind.week,
      firstDay: start,
      lastDay: end,
      anchor: start,
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

  /// The date-only anchor this range was built from (start of period for
  /// Day/Week/Month/Year; [firstDay] for Custom).
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
      case ReportRangeKind.week:
        return ReportRange.week(
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
      case ReportRangeKind.week:
        return ReportRange.week(
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
  /// "Mon Jul 7 - Sun Jul 13", "2026".
  String displayLabel(MaterialLocalizations localizations) {
    switch (kind) {
      case ReportRangeKind.day:
        return localizations.formatMediumDate(firstDay);
      case ReportRangeKind.week:
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
