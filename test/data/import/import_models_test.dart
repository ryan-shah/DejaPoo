import 'package:dejapoo/data/import/import_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyCounts', () {
    test('total sums all type counts', () {
      final dc = DailyCounts(
        date: DateTime(2024, 1, 15),
        typeCounts: {1: 2, 3: 1, 5: 4},
      );
      expect(dc.total, 7);
    });

    test('total is zero for empty typeCounts', () {
      final dc = DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {});
      expect(dc.total, 0);
    });

    test('merge sums counts for same date', () {
      final a = DailyCounts(
        date: DateTime(2024, 1, 15),
        typeCounts: {1: 2, 3: 1},
      );
      final b = DailyCounts(
        date: DateTime(2024, 1, 15),
        typeCounts: {3: 2, 4: 5},
      );
      final merged = a.merge(b);
      expect(merged.typeCounts, {1: 2, 3: 3, 4: 5});
      expect(merged.date, a.date);
    });

    test('merge with disjoint types unions them', () {
      final a = DailyCounts(date: DateTime(2024, 2, 1), typeCounts: {1: 1});
      final b = DailyCounts(date: DateTime(2024, 2, 1), typeCounts: {2: 1});
      final merged = a.merge(b);
      expect(merged.typeCounts, {1: 1, 2: 1});
    });
  });

  group('ImportIssue', () {
    test('toString with no sheet or row', () {
      const issue = ImportIssue(
        severity: ImportIssueSeverity.warning,
        message: 'Something odd',
      );
      expect(issue.toString(), 'warning: Something odd');
    });

    test('toString with sheet only', () {
      const issue = ImportIssue(
        severity: ImportIssueSeverity.error,
        message: 'Bad value',
        sheet: 'Sheet1',
      );
      expect(issue.toString(), 'error: Bad value (sheet "Sheet1")');
    });

    test('toString with sheet and row', () {
      const issue = ImportIssue(
        severity: ImportIssueSeverity.warning,
        message: 'Bad value',
        sheet: 'Sheet1',
        row: 12,
      );
      expect(issue.toString(), 'warning: Bad value (sheet "Sheet1", row 12)');
    });

    test('toString with row only', () {
      const issue = ImportIssue(
        severity: ImportIssueSeverity.error,
        message: 'Missing date',
        row: 5,
      );
      expect(issue.toString(), 'error: Missing date (row 5)');
    });
  });

  group('ImportSummary', () {
    test('hasWarnings true when a warning is present', () {
      const summary = ImportSummary(
        insertedCount: 3,
        skippedCount: 0,
        issues: [
          ImportIssue(
            severity: ImportIssueSeverity.warning,
            message: 'w',
          ),
        ],
      );
      expect(summary.hasWarnings, isTrue);
      expect(summary.hasErrors, isFalse);
    });

    test('hasErrors true when an error is present', () {
      const summary = ImportSummary(
        insertedCount: 3,
        skippedCount: 1,
        issues: [
          ImportIssue(severity: ImportIssueSeverity.error, message: 'e'),
        ],
      );
      expect(summary.hasErrors, isTrue);
      expect(summary.hasWarnings, isFalse);
    });

    test('hasWarnings and hasErrors both false when no issues', () {
      const summary = ImportSummary(
        insertedCount: 3,
        skippedCount: 0,
        issues: [],
      );
      expect(summary.hasWarnings, isFalse);
      expect(summary.hasErrors, isFalse);
    });

    test('totalCount sums inserted and skipped', () {
      const summary = ImportSummary(
        insertedCount: 3,
        skippedCount: 2,
        issues: [],
      );
      expect(summary.totalCount, 5);
    });
  });
}
