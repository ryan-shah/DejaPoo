/// Per-day, per-type counts parsed from a spreadsheet row.
class DailyCounts {
  const DailyCounts({required this.date, required this.typeCounts});

  /// The calendar date (time component ignored).
  final DateTime date;

  /// Counts per Bristol type (1-7). Missing types = 0.
  /// Key is BristolType.number (1-7), value is the count.
  final Map<int, int> typeCounts;

  /// Total events this day.
  int get total => typeCounts.values.fold(0, (s, v) => s + v);

  /// Merges another DailyCounts for the same date by summing counts.
  DailyCounts merge(DailyCounts other) {
    assert(
      date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day,
      'merge requires matching dates',
    );
    final merged = Map<int, int>.from(typeCounts);
    for (final entry in other.typeCounts.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
    }
    return DailyCounts(date: date, typeCounts: merged);
  }
}

/// A non-fatal issue encountered during import.
enum ImportIssueSeverity { warning, error }

class ImportIssue {
  const ImportIssue({
    required this.severity,
    required this.message,
    this.sheet,
    this.row,
  });

  final ImportIssueSeverity severity;
  final String message;
  final String? sheet;
  final int? row;

  @override
  String toString() {
    final location = [
      if (sheet != null) 'sheet "$sheet"',
      if (row != null) 'row $row',
    ].join(', ');
    return '${severity.name}: $message${location.isNotEmpty ? ' ($location)' : ''}';
  }
}

/// Result of parsing one sheet/file.
class SheetParseResult {
  const SheetParseResult({
    required this.rows,
    required this.issues,
    this.sheetName,
  });

  final List<DailyCounts> rows;
  final List<ImportIssue> issues;
  final String? sheetName;
}

/// Overall import summary returned to the UI.
class ImportSummary {
  const ImportSummary({
    required this.insertedCount,
    required this.skippedCount,
    required this.issues,
  });

  final int insertedCount;
  final int skippedCount;
  final List<ImportIssue> issues;

  int get totalCount => insertedCount + skippedCount;
  bool get hasWarnings =>
      issues.any((i) => i.severity == ImportIssueSeverity.warning);
  bool get hasErrors =>
      issues.any((i) => i.severity == ImportIssueSeverity.error);
}
