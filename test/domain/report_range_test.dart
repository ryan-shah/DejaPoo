import 'package:dejapoo/domain/report_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MaterialLocalizations localizations = DefaultMaterialLocalizations();

  group('ReportRange.day', () {
    test('firstDay and lastDay are the same calendar day', () {
      final ReportRange range =
          ReportRange.day(anchor: DateTime(2026, 7, 17, 14, 30));
      expect(range.firstDay, DateTime(2026, 7, 17));
      expect(range.lastDay, DateTime(2026, 7, 17));
    });

    test('next steps forward one day', () {
      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 7, 17));
      expect(range.next().firstDay, DateTime(2026, 7, 18));
    });

    test('previous steps backward one day', () {
      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 7, 17));
      expect(range.previous().firstDay, DateTime(2026, 7, 16));
    });

    test('next crosses month boundary', () {
      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 1, 31));
      expect(range.next().firstDay, DateTime(2026, 2, 1));
    });

    test('previous crosses year boundary', () {
      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 1, 1));
      expect(range.previous().firstDay, DateTime(2025, 12, 31));
    });

    test('displayLabel uses medium date format', () {
      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 7, 17));
      expect(
        range.displayLabel(localizations),
        localizations.formatMediumDate(DateTime(2026, 7, 17)),
      );
    });
  });

  group('ReportRange.week', () {
    test('starts on Monday and ends on Sunday', () {
      // 2026-07-17 is a Friday.
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 17));
      expect(range.firstDay.weekday, DateTime.monday);
      expect(range.lastDay.weekday, DateTime.sunday);
      expect(range.firstDay, DateTime(2026, 7, 13));
      expect(range.lastDay, DateTime(2026, 7, 19));
    });

    test('anchor on Monday stays in the same week', () {
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 13));
      expect(range.firstDay, DateTime(2026, 7, 13));
      expect(range.lastDay, DateTime(2026, 7, 19));
    });

    test('anchor on Sunday stays in the same week', () {
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 19));
      expect(range.firstDay, DateTime(2026, 7, 13));
      expect(range.lastDay, DateTime(2026, 7, 19));
    });

    test('next steps forward 7 days, still Monday-Sunday', () {
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 17));
      final ReportRange nextRange = range.next();
      expect(nextRange.firstDay, DateTime(2026, 7, 20));
      expect(nextRange.lastDay, DateTime(2026, 7, 26));
      expect(nextRange.firstDay.weekday, DateTime.monday);
      expect(nextRange.lastDay.weekday, DateTime.sunday);
    });

    test('previous steps backward 7 days, still Monday-Sunday', () {
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 17));
      final ReportRange prevRange = range.previous();
      expect(prevRange.firstDay, DateTime(2026, 7, 6));
      expect(prevRange.lastDay, DateTime(2026, 7, 12));
    });

    test('week crossing month boundary steps correctly', () {
      // 2026-02-01 is a Sunday, so the week is Jan 26 - Feb 1.
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 2, 1));
      expect(range.firstDay, DateTime(2026, 1, 26));
      expect(range.lastDay, DateTime(2026, 2, 1));
    });

    test('displayLabel formats as short date range', () {
      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 7, 17));
      final String expected =
          '${localizations.formatShortDate(DateTime(2026, 7, 13))} – '
          '${localizations.formatShortDate(DateTime(2026, 7, 19))}';
      expect(range.displayLabel(localizations), expected);
    });
  });

  group('ReportRange.month', () {
    test('July 2026 firstDay is July 1, lastDay is July 31', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 7, 15));
      expect(range.firstDay, DateTime(2026, 7, 1));
      expect(range.lastDay, DateTime(2026, 7, 31));
    });

    test('February 2026 (non-leap) lastDay is Feb 28', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 2, 10));
      expect(range.lastDay, DateTime(2026, 2, 28));
    });

    test('February 2028 (leap) lastDay is Feb 29', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2028, 2, 10));
      expect(range.lastDay, DateTime(2028, 2, 29));
    });

    test('next from January steps to February with correct length', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 1, 31));
      final ReportRange nextRange = range.next();
      expect(nextRange.firstDay, DateTime(2026, 2, 1));
      expect(nextRange.lastDay, DateTime(2026, 2, 28));
    });

    test('previous from February steps back to January', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 2, 10));
      final ReportRange prevRange = range.previous();
      expect(prevRange.firstDay, DateTime(2026, 1, 1));
      expect(prevRange.lastDay, DateTime(2026, 1, 31));
    });

    test('next from December steps to January of next year', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 12, 5));
      final ReportRange nextRange = range.next();
      expect(nextRange.firstDay, DateTime(2027, 1, 1));
      expect(nextRange.lastDay, DateTime(2027, 1, 31));
    });

    test('previous from January steps to December of previous year', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 1, 5));
      final ReportRange prevRange = range.previous();
      expect(prevRange.firstDay, DateTime(2025, 12, 1));
      expect(prevRange.lastDay, DateTime(2025, 12, 31));
    });

    test('displayLabel formats as month year', () {
      final ReportRange range =
          ReportRange.month(anchor: DateTime(2026, 7, 15));
      expect(
        range.displayLabel(localizations),
        localizations.formatMonthYear(DateTime(2026, 7, 1)),
      );
    });
  });

  group('ReportRange.year', () {
    test('firstDay is Jan 1, lastDay is Dec 31', () {
      final ReportRange range = ReportRange.year(anchor: DateTime(2026, 7, 1));
      expect(range.firstDay, DateTime(2026, 1, 1));
      expect(range.lastDay, DateTime(2026, 12, 31));
    });

    test('next steps forward one year', () {
      final ReportRange range = ReportRange.year(anchor: DateTime(2026, 7, 1));
      final ReportRange nextRange = range.next();
      expect(nextRange.firstDay, DateTime(2027, 1, 1));
      expect(nextRange.lastDay, DateTime(2027, 12, 31));
    });

    test('previous steps backward one year', () {
      final ReportRange range = ReportRange.year(anchor: DateTime(2026, 7, 1));
      final ReportRange prevRange = range.previous();
      expect(prevRange.firstDay, DateTime(2025, 1, 1));
      expect(prevRange.lastDay, DateTime(2025, 12, 31));
    });

    test('displayLabel is just the year', () {
      final ReportRange range = ReportRange.year(anchor: DateTime(2026, 7, 1));
      expect(range.displayLabel(localizations), '2026');
    });
  });

  group('ReportRange.custom', () {
    test('firstDay and lastDay match from/to', () {
      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 10),
      );
      expect(range.firstDay, DateTime(2026, 7, 1));
      expect(range.lastDay, DateTime(2026, 7, 10));
    });

    test('swapped from/to are normalized', () {
      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 10),
        to: DateTime(2026, 7, 1),
      );
      expect(range.firstDay, DateTime(2026, 7, 1));
      expect(range.lastDay, DateTime(2026, 7, 10));
    });

    test('next steps forward by the range length, staying adjacent', () {
      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 5),
      ); // 5 days
      final ReportRange nextRange = range.next();
      expect(nextRange.firstDay, DateTime(2026, 7, 6));
      expect(nextRange.lastDay, DateTime(2026, 7, 10));
    });

    test('previous steps backward by the range length', () {
      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 6),
        to: DateTime(2026, 7, 10),
      ); // 5 days
      final ReportRange prevRange = range.previous();
      expect(prevRange.firstDay, DateTime(2026, 7, 1));
      expect(prevRange.lastDay, DateTime(2026, 7, 5));
    });

    test('displayLabel formats as short date range', () {
      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 10),
      );
      final String expected =
          '${localizations.formatShortDate(DateTime(2026, 7, 1))} – '
          '${localizations.formatShortDate(DateTime(2026, 7, 10))}';
      expect(range.displayLabel(localizations), expected);
    });
  });

  group('equality', () {
    test('same kind and days are equal', () {
      final ReportRange a = ReportRange.month(anchor: DateTime(2026, 7, 1));
      final ReportRange b = ReportRange.month(anchor: DateTime(2026, 7, 20));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different kinds with same days are not equal', () {
      final ReportRange week = ReportRange.week(anchor: DateTime(2026, 7, 13));
      final ReportRange custom = ReportRange.custom(
        from: DateTime(2026, 7, 13),
        to: DateTime(2026, 7, 19),
      );
      expect(week == custom, isFalse);
    });
  });
}
