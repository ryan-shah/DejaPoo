import 'package:csv/csv.dart';
import 'package:dejapoo/domain/bowel_movement.dart';

/// Generates a flat CSV string shaped like the original historical
/// spreadsheet layout, re-importable by [CsvParser]
/// (see `lib/data/import/csv_parser.dart`).
///
/// Column layout (no year-sheet separation, all years in one file):
/// MONTH,DATE,TYPE 1,TYPE 2,...,TYPE 7,TOTAL
///
/// The date column uses ISO format (yyyy-MM-dd), which [CsvParser] parses
/// via `DateTime.tryParse`.
class CsvExport {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Generates CSV text from a list of [BowelMovement] records.
  ///
  /// Soft-deleted movements ([BowelMovement.deletedAt] non-null) are
  /// excluded. Movements are grouped by calendar day (using the local
  /// [BowelMovement.occurredAt] date part) and counted per Bristol type;
  /// multiple events on the same day (timed or date-only) are summed. Days
  /// are sorted chronologically.
  static String generate(List<BowelMovement> movements) {
    final byDay = <DateTime, Map<int, int>>{};
    for (final m in movements) {
      if (m.deletedAt != null) continue;
      final day = DateTime(
        m.occurredAt.year,
        m.occurredAt.month,
        m.occurredAt.day,
      );
      final counts = byDay.putIfAbsent(day, () => {});
      final typeNum = m.bristolType.number;
      counts[typeNum] = (counts[typeNum] ?? 0) + 1;
    }

    final sortedDates = byDay.keys.toList()..sort();

    final rows = <List<dynamic>>[];
    rows.add([
      'MONTH',
      'DATE',
      'TYPE 1',
      'TYPE 2',
      'TYPE 3',
      'TYPE 4',
      'TYPE 5',
      'TYPE 6',
      'TYPE 7',
      'TOTAL',
    ]);

    int? lastMonthWritten;
    int? lastYearWritten;
    for (final date in sortedDates) {
      final counts = byDay[date]!;
      final row = <dynamic>[];

      // Column A: month name, only on first occurrence of that month
      // (tracked per year, since the CSV spans multiple years).
      if (date.month != lastMonthWritten || date.year != lastYearWritten) {
        row.add(_monthNames[date.month - 1]);
        lastMonthWritten = date.month;
        lastYearWritten = date.year;
      } else {
        row.add('');
      }

      // Column B: ISO date.
      row.add(
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
      );

      // Columns C-I: Bristol Type 1-7 counts. 0 -> blank.
      var total = 0;
      for (var type = 1; type <= 7; type++) {
        final count = counts[type] ?? 0;
        row.add(count == 0 ? '' : count);
        total += count;
      }

      // Column J: total.
      row.add(total);

      rows.add(row);
    }

    return Csv().encode(rows);
  }
}
