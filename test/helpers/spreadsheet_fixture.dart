import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Builds synthetic XLSX bytes in-memory, shaped like the real
/// "Alex Bowels.xlsx" Google Sheets export, for use in tests.
///
/// No binary fixture files are committed — everything is generated on the
/// fly via the `excel` package, using the same cell-value types the real
/// export produces (raw Excel serial doubles in column B, not a "nice"
/// [DateCellValue], to exercise the parser's real code path).
class SpreadsheetFixture {
  /// Creates XLSX bytes for the given year-sheets.
  ///
  /// [sheets] maps a sheet name (e.g. "2024") to a list of row specs. Each
  /// row spec is a map with a `date` (`DateTime`) and a `counts`
  /// (`Map<int, int>`, Bristol type number 1-7 -> count) entry.
  ///
  /// Optional per-row overrides for edge-case testing:
  ///  - `dateCellValue`: a [CellValue] to write into column B directly,
  ///    overriding the default raw-serial-double encoding of `date`.
  ///  - `sideStats`: a `Map<int, CellValue>` of column-index -> value to
  ///    write starting at column L (index 11), simulating the side stat
  ///    table that shares data rows and must never be read.
  ///  - `total`: an explicit total to write into column J, overriding the
  ///    computed sum of `counts` (used to test the mismatch-warning path).
  static Uint8List createXlsx(
    Map<String, List<Map<String, dynamic>>> sheets, {
    List<String> extraSheetNames = const [],
  }) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();
    final wantedSheetNames = {...sheets.keys, ...extraSheetNames};

    for (final entry in sheets.entries) {
      final sheetName = entry.key;
      final rows = entry.value;
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
      for (var r = 0; r < rows.length; r++) {
        final rowSpec = rows[r];
        final rowIndex = r + 2;
        final date = rowSpec['date'] as DateTime?;
        final counts = (rowSpec['counts'] as Map<int, int>?) ?? const {};
        final dateCellValue = rowSpec['dateCellValue'] as CellValue?;
        final sideStats = rowSpec['sideStats'] as Map<int, CellValue>?;
        final totalOverride = rowSpec['total'] as num?;

        // Column B: date, as a raw Excel serial double by default.
        if (dateCellValue != null) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = dateCellValue;
        } else if (date != null) {
          final serial = _toExcelSerial(date);
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = DoubleCellValue(serial.toDouble());
        }

        // Columns C-I (indices 2-8): Bristol Type 1-7 counts.
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

        // Column J (index 9): total (SUM formula in the real sheet; here a
        // literal value, since the excel package can't set cached formula
        // results and the parser only reads cached values anyway).
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = DoubleCellValue((totalOverride ?? total).toDouble());

        // Optional side-stat columns (L onward = index 11+) sharing this
        // data row — must never be read by the parser.
        if (sideStats != null) {
          for (final e in sideStats.entries) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: e.key,
                    rowIndex: rowIndex,
                  ),
                )
                .value = e.value;
          }
        }
      }
    }

    for (final extraName in extraSheetNames) {
      final sheet = excel[extraName];
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('extra');
    }

    if (defaultSheetName != null &&
        !wantedSheetNames.contains(defaultSheetName)) {
      excel.delete(defaultSheetName);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Converts a [DateTime] to an Excel serial date number.
  ///
  /// Excel's epoch is 1899-12-30. Does the arithmetic in UTC to avoid a
  /// local-time DST trap: differencing two local `DateTime`s that sit on
  /// opposite sides of a DST transition doesn't yield a whole number of
  /// days, so `.inDays` truncates and silently drops a day.
  static int _toExcelSerial(DateTime date) {
    final epoch = DateTime.utc(1899, 12, 30);
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return utcDate.difference(epoch).inDays;
  }
}
