import 'dart:typed_data';

import 'package:dejapoo/data/import/import_models.dart';
import 'package:excel/excel.dart';

/// Parses the historical Google-Sheets export ("Alex Bowels.xlsx" and
/// similarly-shaped workbooks) into [SheetParseResult]s, one per year-sheet.
///
/// Layout assumptions (see designs/PHASE_4_PLAN.md for the full spec):
///  - Sheets are named with a 4-digit year (e.g. "2024"); anything else is
///    skipped with a warning.
///  - Row 1 is a title, row 2 is headers, data starts at row 3 (index 2).
///  - Column A (month name, only on the 1st of the month) is never read.
///  - Column B holds the date, exported as a raw Excel serial number in the
///    vast majority of cases, but the `excel` package can also surface it as
///    a proper date/datetime cell value depending on how the sheet was
///    authored — all are handled.
///  - Columns C-I (indices 2-8) are Bristol Type 1-7 counts; blank = 0.
///  - Column J (index 9) is `=SUM(C:I)`, used only for a best-effort mismatch
///    warning (see note on [_parseCellAsDouble] about formula cells).
///  - A "side stat" table shares these data rows starting at column L
///    (index 11) onward — those columns are never read.
///  - Whether a row is a data row at all is gated entirely on "does column B
///    parse as a date"; this skips the title, header, KEY legend, and blank
///    rows uniformly.
class XlsxParser {
  /// The last data column read (TOTAL, column J = index 9). Columns beyond
  /// this belong to the side stat table and must never be touched.
  static const int _lastDataColumnIndex = 9;

  /// Parses an XLSX file from raw bytes.
  ///
  /// Returns one [SheetParseResult] per sheet found in the workbook. Sheets
  /// whose name isn't a 4-digit year produce an empty result carrying a
  /// warning [ImportIssue] rather than being silently dropped.
  List<SheetParseResult> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final results = <SheetParseResult>[];

    for (final sheetName in excel.tables.keys) {
      if (!RegExp(r'^\d{4}$').hasMatch(sheetName)) {
        results.add(
          SheetParseResult(
            rows: const [],
            issues: [
              ImportIssue(
                severity: ImportIssueSeverity.warning,
                message: 'Skipped non-year sheet "$sheetName"',
                sheet: sheetName,
              ),
            ],
            sheetName: sheetName,
          ),
        );
        continue;
      }

      results.add(_parseSheet(excel.tables[sheetName]!, sheetName));
    }

    return results;
  }

  SheetParseResult _parseSheet(Sheet sheet, String sheetName) {
    final rows = <DailyCounts>[];
    final issues = <ImportIssue>[];
    final sheetYear = int.parse(sheetName);

    for (var rowIdx = 0; rowIdx < sheet.maxRows; rowIdx++) {
      final row = sheet.row(rowIdx);

      // Row gate: column B (index 1) must parse as a date. This uniformly
      // skips the title row, header row, KEY legend rows, and blank rows.
      final dateCell = row.length > 1 ? row[1] : null;
      final date = _parseDate(dateCell);
      if (date == null) continue;

      final humanRow = rowIdx + 1;

      if (date.year != sheetYear) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.warning,
            message:
                'Date year ${date.year} differs from sheet year $sheetYear',
            sheet: sheetName,
            row: humanRow,
          ),
        );
      }

      // Columns C-I (indices 2-8) -> Bristol Type 1-7 counts.
      final typeCounts = <int, int>{};
      var hasInvalidCount = false;

      for (var col = 2; col <= 8; col++) {
        final typeNum = col - 1;
        final cell = col < row.length ? row[col] : null;
        final value = _parseCellAsDouble(cell);
        if (value == null) continue; // blank cell = 0

        if (value < 0 || value != value.roundToDouble()) {
          hasInvalidCount = true;
          issues.add(
            ImportIssue(
              severity: ImportIssueSeverity.error,
              message:
                  'Non-integral or negative count ($value) for Type $typeNum',
              sheet: sheetName,
              row: humanRow,
            ),
          );
        } else if (value > 0) {
          typeCounts[typeNum] = value.round();
        }
      }

      if (hasInvalidCount) continue; // skip the whole row

      // Column J (index _lastDataColumnIndex) -> reported total. Never read
      // past this column; the side stat table starts at column L.
      final totalCell =
          row.length > _lastDataColumnIndex ? row[_lastDataColumnIndex] : null;
      final totalValue = _parseCellAsDouble(totalCell);
      final computedTotal = typeCounts.values.fold<int>(0, (s, v) => s + v);
      if (totalValue != null && totalValue.round() != computedTotal) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.warning,
            message:
                'Total column (${totalValue.round()}) != sum of types ($computedTotal)',
            sheet: sheetName,
            row: humanRow,
          ),
        );
      }

      rows.add(DailyCounts(date: date, typeCounts: typeCounts));
    }

    return SheetParseResult(rows: rows, issues: issues, sheetName: sheetName);
  }

  /// Parses a column-B cell as a calendar date, handling every cell-value
  /// shape the `excel` package can hand back for a date: a proper date/
  /// datetime value, or a raw Excel serial number surfaced as an int or
  /// double. Returns `null` (not a date row) for anything else, including
  /// blank cells and text (e.g. the "KEY" legend rows).
  DateTime? _parseDate(Data? cell) {
    final value = cell?.value;
    if (value == null) return null;

    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is DateTimeCellValue) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is IntCellValue) {
      return _fromExcelSerial(value.value.toDouble());
    }
    if (value is DoubleCellValue) {
      return _fromExcelSerial(value.value);
    }
    return null;
  }

  /// Converts an Excel serial date number to a [DateTime].
  ///
  /// Excel's epoch is 1899-12-30 (not 1900-01-01) to account for the
  /// historical Lotus 1-2-3 leap-year bug that Excel preserved for
  /// compatibility.
  ///
  /// Uses UTC for the day-arithmetic to avoid the local-time DST trap: doing
  /// this math in local time can land the result on the wrong day whenever
  /// the epoch and target date sit on opposite sides of a DST transition
  /// (their UTC offsets differ, so `add(Duration(days: n))` doesn't land on
  /// local midnight of the intended day). The result is then reduced to a
  /// pure calendar date, so callers get a local [DateTime] regardless.
  static DateTime? _fromExcelSerial(double serial) {
    if (serial < 1) return null;
    final epoch = DateTime.utc(1899, 12, 30);
    final utcDate = epoch.add(Duration(days: serial.round()));
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  /// Reads a numeric cell value as a [double].
  ///
  /// Note: the `excel` package does not expose the cached `<v>` result of a
  /// formula cell — for a cell containing e.g. `=SUM(C3:I3)` it only exposes
  /// the formula text via [FormulaCellValue.formula]. That means the column
  /// J total-mismatch check below is best-effort: it fires when column J was
  /// exported as a literal number, and is silently skipped (no warning, no
  /// error) when it's a live formula the package can't give us a value for.
  double? _parseCellAsDouble(Data? cell) {
    final value = cell?.value;
    if (value == null) return null;
    if (value is DoubleCellValue) return value.value;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is TextCellValue) return double.tryParse(value.value.text ?? '');
    if (value is FormulaCellValue) return double.tryParse(value.formula);
    return null;
  }
}
