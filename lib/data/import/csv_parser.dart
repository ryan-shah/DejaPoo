import 'package:csv/csv.dart';
import 'package:dejapoo/data/import/import_models.dart';

/// Parses a CSV year-sheet (one CSV file = one year) into [DailyCounts].
///
/// Mirrors the XLSX layout but with text-based date columns:
/// - Row 1: title. Row 2: headers. Data from row 3.
/// - Column A: month name — ignored.
/// - Column B: date (ISO, US format, or Excel serial number).
/// - Columns C-I: numeric counts for Bristol Type 1-7 (blank = 0).
/// - Column J: total — read for mismatch warning only; per-type cells are
///   authoritative.
class CsvParser {
  /// Parses CSV text representing a single year-sheet.
  SheetParseResult parse(String csvText) {
    // dynamicTyping defaults to false, so fields stay as Strings — we do
    // our own numeric/date parsing below.
    final rows = Csv().decode(csvText);

    final dailyCounts = <DailyCounts>[];
    final issues = <ImportIssue>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 1; // 1-based for user messages

      // Need at least column B (index 1) for date
      if (row.length < 2) continue;

      // Column B date gate
      final dateStr = row[1].toString().trim();
      if (dateStr.isEmpty) continue;

      final date = _parseDate(dateStr);
      if (date == null) continue; // skip non-date rows (title, headers, etc.)

      // Read columns C-I (indices 2-8) for Type 1-7. Never read past column J.
      final typeCounts = <int, int>{};
      bool hasInvalidCount = false;

      for (int col = 2; col <= 8 && col < row.length; col++) {
        final typeNum = col - 1;
        final cellStr = row[col].toString().trim();
        if (cellStr.isEmpty) continue; // blank = 0

        final value = double.tryParse(cellStr);
        if (value == null || value < 0 || value != value.roundToDouble()) {
          hasInvalidCount = true;
          issues.add(
            ImportIssue(
              severity: ImportIssueSeverity.error,
              message:
                  'Non-integral or negative count ($cellStr) for Type $typeNum',
              row: rowNum,
            ),
          );
          break;
        }
        if (value > 0) {
          typeCounts[typeNum] = value.round();
        }
      }

      if (hasInvalidCount) continue;

      // Check total column J (index 9)
      if (row.length > 9) {
        final totalStr = row[9].toString().trim();
        final totalValue = double.tryParse(totalStr);
        final computedTotal = typeCounts.values.fold(0, (s, v) => s + v);
        if (totalValue != null && totalValue.round() != computedTotal) {
          issues.add(
            ImportIssue(
              severity: ImportIssueSeverity.warning,
              message:
                  'Total column (${totalValue.round()}) != sum of types ($computedTotal)',
              row: rowNum,
            ),
          );
        }
      }

      dailyCounts.add(DailyCounts(date: date, typeCounts: typeCounts));
    }

    return SheetParseResult(rows: dailyCounts, issues: issues);
  }

  /// Parses column B date string.
  /// Tries: ISO (2024-01-15), US (1/15/2024), US short (1/15/24), Excel
  /// serial number. Returns null for anything unrecognized (e.g. header
  /// text), so such rows are skipped rather than erroring.
  DateTime? _parseDate(String s) {
    // ISO format: 2024-01-15
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // US format: M/d/yyyy or M/d/yy
    final usMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(s);
    if (usMatch != null) {
      final month = int.parse(usMatch.group(1)!);
      final day = int.parse(usMatch.group(2)!);
      var year = int.parse(usMatch.group(3)!);
      if (year < 100) {
        year += 2000; // 24 -> 2024
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // Excel serial number
    final serial = double.tryParse(s);
    if (serial != null && serial >= 1 && serial <= 200000) {
      final epoch = DateTime(1899, 12, 30);
      return epoch.add(Duration(days: serial.round()));
    }

    return null;
  }
}
