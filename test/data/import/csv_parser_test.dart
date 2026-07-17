import 'package:dejapoo/data/import/csv_parser.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvParser', () {
    late CsvParser parser;

    setUp(() {
      parser = CsvParser();
    });

    test('basic happy path parses DailyCounts', () {
      const csv = ''',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL
January,2024-01-01,1,,2,,,,,3
,2024-01-02,,,,1,,,,1
''';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(2));

      final day1 = result.rows[0];
      expect(day1.date, DateTime(2024, 1, 1));
      expect(day1.typeCounts, {1: 1, 3: 2});
      expect(day1.total, 3);

      final day2 = result.rows[1];
      expect(day2.date, DateTime(2024, 1, 2));
      expect(day2.typeCounts, {4: 1});
      expect(day2.total, 1);

      expect(
        result.issues.where((i) => i.severity == ImportIssueSeverity.error),
        isEmpty,
      );
    });

    test('quoted fields are parsed correctly', () {
      const csv = '"","DATE","TYPE 1","TYPE 2","TYPE 3","TYPE 4","TYPE 5","TYPE 6","TYPE 7","TOTAL"\n'
          '"January","2024-01-01","1","","2","","","","","3"\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 1));
      expect(result.rows[0].typeCounts, {1: 1, 3: 2});
    });

    test('CRLF line endings are handled', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\r\n'
          'January,2024-01-01,1,,2,,,,,3\r\n'
          ',2024-01-02,,,,1,,,,1\r\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(2));
      expect(result.rows[0].date, DateTime(2024, 1, 1));
      expect(result.rows[1].date, DateTime(2024, 1, 2));
    });

    test('date format: ISO (2024-01-15)', () {
      const csv = ',DATE,TYPE 1\n,2024-01-15,1\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 15));
    });

    test('date format: M/d/yyyy (1/15/2024)', () {
      const csv = ',DATE,TYPE 1\n,1/15/2024,1\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 15));
    });

    test('date format: M/d/yy (1/15/24)', () {
      const csv = ',DATE,TYPE 1\n,1/15/24,1\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 15));
    });

    test('date format: Excel serial number', () {
      // 45292 is the Excel serial for 2024-01-01 (epoch 1899-12-30).
      const csv = ',DATE,TYPE 1\n,45292,1\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 1));
    });

    test('non-date rows (title, headers, blanks) are skipped', () {
      const csv = ',,TYPES OF POOP,,,,,,,\n'
          'MONTH,DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\n'
          ',,,,,,,,,\n'
          'January,2024-01-01,1,,,,,,,1\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 1));
    });

    test('blank cells are treated as zero', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7\n'
          ',2024-01-01,,,3,,,,\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].typeCounts, {3: 3});
    });

    test('all-blank counts row is a valid zero-event day', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\n'
          ',2024-01-01,,,,,,,,\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].typeCounts, isEmpty);
      expect(result.rows[0].total, 0);
    });

    test('total mismatch produces a warning but still keeps the row', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\n'
          ',2024-01-01,1,,2,,,,,99\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].typeCounts, {1: 1, 3: 2});

      final warnings = result.issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(warnings, hasLength(1));
      expect(warnings.first.message, contains('99'));
      expect(warnings.first.row, 2);
    });

    test('negative or non-integral counts produce an error and skip the row', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL\n'
          ',2024-01-01,-1,,2,,,,,1\n'
          ',2024-01-02,1.5,,,,,,,1.5\n'
          ',2024-01-03,1,,,,,,,1\n';
      final result = parser.parse(csv);

      // Only the valid row (2024-01-03) should survive.
      expect(result.rows, hasLength(1));
      expect(result.rows[0].date, DateTime(2024, 1, 3));

      final errors = result.issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      expect(errors, hasLength(2));
      expect(errors[0].row, 2);
      expect(errors[1].row, 3);
    });

    test('never reads past column J (TOTAL)', () {
      const csv = ',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL,NOTES,EXTRA\n'
          ',2024-01-01,1,,,,,,,1,ignored,also ignored\n';
      final result = parser.parse(csv);
      expect(result.rows, hasLength(1));
      expect(result.rows[0].typeCounts, {1: 1});
      // No mismatch warning since total (1) matches sum (1), and no error
      // from the extra trailing columns.
      expect(result.issues, isEmpty);
    });
  });
}
