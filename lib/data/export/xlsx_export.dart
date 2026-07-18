import 'dart:typed_data';

import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:excel/excel.dart';

/// Generates XLSX bytes shaped like the original historical spreadsheet
/// ("Alex Bowels.xlsx"), so exported data can be losslessly re-imported by
/// [XlsxParser] (see `lib/data/import/xlsx_parser.dart`).
///
/// Layout (one sheet per year):
///  - Row 1: title, "TYPES OF POOP" in column C.
///  - Row 2: headers — MONTH, DATE, TYPE 1..7, TOTAL (columns A-J).
///  - Data rows from row 3: column A = month name (first occurrence of that
///    month only), column B = date as an Excel serial number, columns C-I =
///    Bristol type 1-7 counts (0 counts left blank), column J = total.
class XlsxExport {
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

  /// Generates XLSX bytes from a list of [BowelMovement] records.
  ///
  /// Soft-deleted movements ([BowelMovement.deletedAt] non-null) are
  /// excluded. Movements are grouped by calendar day (using the local
  /// [BowelMovement.occurredAt] date part) and counted per Bristol type;
  /// multiple events on the same day (timed or date-only) are summed.
  static Uint8List generate(List<BowelMovement> movements) {
    final byYear = _groupByYearAndDay(movements);

    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();

    final sortedYears = byYear.keys.toList()..sort();
    for (final year in sortedYears) {
      final sheetName = year.toString();
      final sheet = excel[sheetName];

      // Row 0 (index 0): title.
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = TextCellValue('TYPES OF POOP');

      // Row 1 (index 1): headers.
      const headers = [
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
      ];
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
            .value = TextCellValue(headers[i]);
      }

      // Data rows from row 2 (index 2, i.e. spreadsheet row 3).
      final daysByDate = byYear[year]!;
      final sortedDates = daysByDate.keys.toList()..sort();

      int? lastMonthWritten;
      for (var r = 0; r < sortedDates.length; r++) {
        final date = sortedDates[r];
        final counts = daysByDate[date]!;
        final rowIndex = r + 2;

        // Column A: month name, only on first occurrence of that month.
        if (date.month != lastMonthWritten) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = TextCellValue(_monthNames[date.month - 1]);
          lastMonthWritten = date.month;
        }

        // Column B: date as Excel serial number.
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(_toExcelSerial(date).toDouble());

        // Columns C-I (indices 2-8): Bristol Type 1-7 counts. 0 -> blank.
        var total = 0;
        for (var type = 1; type <= 7; type++) {
          final count = counts[type] ?? 0;
          if (count != 0) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: type + 1,
                    rowIndex: rowIndex,
                  ),
                )
                .value = DoubleCellValue(count.toDouble());
          }
          total += count;
        }

        // Column J (index 9): total.
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(total.toDouble());
      }
    }

    final wantedSheetNames = sortedYears.map((y) => y.toString()).toSet();
    if (defaultSheetName != null &&
        wantedSheetNames.isNotEmpty &&
        !wantedSheetNames.contains(defaultSheetName)) {
      excel.delete(defaultSheetName);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Groups movements by year, then by calendar day, then counts per
  /// Bristol type. Excludes soft-deleted movements.
  static Map<int, Map<DateTime, Map<int, int>>> _groupByYearAndDay(
    List<BowelMovement> movements,
  ) {
    final result = <int, Map<DateTime, Map<int, int>>>{};
    for (final m in movements) {
      if (m.deletedAt != null) continue;
      final day = DateTime(
        m.occurredAt.year,
        m.occurredAt.month,
        m.occurredAt.day,
      );
      final year = day.year;
      final yearMap = result.putIfAbsent(year, () => {});
      final dayCounts = yearMap.putIfAbsent(day, () => {});
      final typeNum = m.bristolType.number;
      dayCounts[typeNum] = (dayCounts[typeNum] ?? 0) + 1;
    }
    return result;
  }

  /// Converts a [DateTime] to an Excel serial date number.
  ///
  /// Excel's epoch is 1899-12-30. Does the arithmetic in UTC to avoid a
  /// local-time DST trap (see `test/helpers/spreadsheet_fixture.dart`).
  static int _toExcelSerial(DateTime date) {
    final epoch = DateTime.utc(1899, 12, 30);
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return utcDate.difference(epoch).inDays;
  }
}
