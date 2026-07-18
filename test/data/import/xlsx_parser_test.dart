import 'dart:typed_data';

import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/xlsx_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spreadsheet_fixture.dart';

void main() {
  late XlsxParser parser;

  setUp(() {
    parser = XlsxParser();
  });

  test('parses basic year sheet with correct counts', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {3: 1, 4: 2},
        },
        {
          'date': DateTime(2024, 1, 2),
          'counts': {1: 1},
        },
      ],
    });

    final results = parser.parse(bytes);

    expect(results, hasLength(1));
    final result = results.single;
    expect(result.sheetName, '2024');
    expect(result.rows, hasLength(2));
    expect(result.rows[0].date, DateTime(2024, 1, 1));
    expect(result.rows[0].typeCounts, {3: 1, 4: 2});
    expect(result.rows[1].date, DateTime(2024, 1, 2));
    expect(result.rows[1].typeCounts, {1: 1});
    expect(result.issues, isEmpty);
  });

  test(
    'skips non-date rows: title, headers, KEY legend, blanks via column-B gate',
    () {
      final excel = Excel.createExcel();
      final sheet = excel['2024'];
      // Row 0: title (as SpreadsheetFixture would write it).
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('TYPES OF POOP');
      // Row 1: headers.
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
          TextCellValue('DATE');
      // Row 2: a real data row.
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
          const DoubleCellValue(45292.0); // 2024-01-01
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value =
          const DoubleCellValue(1.0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2)).value =
          const DoubleCellValue(1.0);
      // Row 3: a "KEY" legend row — text in column B, not a date.
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value =
          TextCellValue('KEY');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value =
          TextCellValue('Type 1 = Separate hard lumps');
      // Row 4: completely blank (no cells written) — implicit skip.
      excel.delete(excel.getDefaultSheet()!);

      final results = parser.parse(
        Uint8List.fromList(excel.encode()!),
      );

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.rows, hasLength(1));
      expect(result.rows.single.date, DateTime(2024, 1, 1));
      expect(result.rows.single.typeCounts, {2: 1});
    },
  );

  test('blank count cells are 0; an all-blank row is a valid zero-event day', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {'date': DateTime(2024, 1, 1), 'counts': <int, int>{}},
      ],
    });

    final results = parser.parse(bytes);

    final row = results.single.rows.single;
    expect(row.typeCounts, isEmpty);
    expect(row.total, 0);
  });

  test('total column mismatch produces a warning but the row still imports', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {3: 1, 4: 2},
          'total': 99, // deliberately wrong
        },
      ],
    });

    final results = parser.parse(bytes);
    final result = results.single;

    expect(result.rows, hasLength(1));
    expect(result.rows.single.typeCounts, {3: 1, 4: 2});
    expect(
      result.issues,
      contains(
        predicate<ImportIssue>(
          (i) =>
              i.severity == ImportIssueSeverity.warning &&
              i.message.contains('Total column'),
        ),
      ),
    );
  });

  test('negative or non-integral counts produce an error and skip the row', () {
    final excel = Excel.createExcel();
    final sheet = excel['2024'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        const DoubleCellValue(45292.0); // 2024-01-01
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value =
        const DoubleCellValue(-1.0); // negative
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value =
        const DoubleCellValue(45293.0); // 2024-01-02
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value =
        const DoubleCellValue(1.5); // non-integral
    excel.delete(excel.getDefaultSheet()!);

    final results = parser.parse(Uint8List.fromList(excel.encode()!));
    final result = results.single;

    expect(result.rows, isEmpty);
    expect(
      result.issues.where((i) => i.severity == ImportIssueSeverity.error),
      hasLength(2),
    );
  });

  test('handles DoubleCellValue in column B (primary real-world encoding)', () {
    final excel = Excel.createExcel();
    final sheet = excel['2024'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        const DoubleCellValue(45292.0);
    excel.delete(excel.getDefaultSheet()!);

    final results = parser.parse(Uint8List.fromList(excel.encode()!));
    expect(results.single.rows.single.date, DateTime(2024, 1, 1));
  });

  test('handles IntCellValue in column B', () {
    final excel = Excel.createExcel();
    final sheet = excel['2024'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        const IntCellValue(45292);
    excel.delete(excel.getDefaultSheet()!);

    final results = parser.parse(Uint8List.fromList(excel.encode()!));
    expect(results.single.rows.single.date, DateTime(2024, 1, 1));
  });

  test('handles DateCellValue in column B', () {
    final excel = Excel.createExcel();
    final sheet = excel['2024'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        const DateCellValue(year: 2024, month: 1, day: 1);
    excel.delete(excel.getDefaultSheet()!);

    final results = parser.parse(Uint8List.fromList(excel.encode()!));
    expect(results.single.rows.single.date, DateTime(2024, 1, 1));
  });

  test('handles DateTimeCellValue in column B', () {
    final excel = Excel.createExcel();
    final sheet = excel['2024'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        const DateTimeCellValue(
      year: 2024,
      month: 1,
      day: 1,
      hour: 0,
      minute: 0,
    );
    excel.delete(excel.getDefaultSheet()!);

    final results = parser.parse(Uint8List.fromList(excel.encode()!));
    expect(results.single.rows.single.date, DateTime(2024, 1, 1));
  });

  test('never reads past column J: side stat columns L-Q are ignored', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {5: 3},
          'sideStats': {
            11: const DoubleCellValue(999.0), // L
            12: TextCellValue('some stat'), // M
            13: const DoubleCellValue(-42.0), // N — would be an error if read
            15: const DoubleCellValue(1234.0), // P
            16: TextCellValue('another'), // Q
          },
        },
      ],
    });

    final results = parser.parse(bytes);
    final result = results.single;

    expect(result.rows, hasLength(1));
    expect(result.rows.single.typeCounts, {5: 3});
    // No errors from the negative value planted in column N.
    expect(
      result.issues.where((i) => i.severity == ImportIssueSeverity.error),
      isEmpty,
    );
  });

  test('sheet-name year differing from the date year produces a warning; dates win', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2025, 1, 1), // wrong year for this sheet
          'counts': {1: 1},
        },
      ],
    });

    final results = parser.parse(bytes);
    final result = results.single;

    expect(result.rows.single.date, DateTime(2025, 1, 1));
    expect(
      result.issues,
      contains(
        predicate<ImportIssue>(
          (i) =>
              i.severity == ImportIssueSeverity.warning &&
              i.message.contains('differs from sheet year'),
        ),
      ),
    );
  });

  test('duplicate dates within a sheet are passed through unmerged', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {1: 1},
        },
        {
          'date': DateTime(2024, 1, 1),
          'counts': {2: 1},
        },
      ],
    });

    final results = parser.parse(bytes);
    final result = results.single;

    expect(result.rows, hasLength(2));
    expect(result.rows[0].date, result.rows[1].date);
  });

  test('parses a full leap year (2024, 366 rows)', () {
    final start = DateTime(2024, 1, 1);
    final rows = List.generate(
      366,
      (i) => {
        'date': start.add(Duration(days: i)),
        'counts': <int, int>{1: 1},
      },
    );

    final bytes = SpreadsheetFixture.createXlsx({'2024': rows});
    final results = parser.parse(bytes);

    expect(results.single.rows, hasLength(366));
    expect(results.single.rows.last.date, DateTime(2024, 12, 31));
  });

  test('parses a partial year with blank trailing days as zero-event days', () {
    final rows = [
      for (var i = 0; i < 100; i++)
        {
          'date': DateTime(2026, 1, 1).add(Duration(days: i)),
          'counts': {1: 1},
        },
      for (var i = 100; i < 200; i++)
        {
          'date': DateTime(2026, 1, 1).add(Duration(days: i)),
          'counts': <int, int>{},
        },
    ];

    final bytes = SpreadsheetFixture.createXlsx({'2026': rows});
    final results = parser.parse(bytes);

    expect(results.single.rows, hasLength(200));
    expect(results.single.rows[150].typeCounts, isEmpty);
    expect(results.single.rows[150].total, 0);
  });

  test('non-year sheet names are skipped with a warning and no rows', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {1: 1},
        },
      ],
    }, extraSheetNames: const ['Summary', 'Notes']);

    final results = parser.parse(bytes);

    expect(results, hasLength(3));
    final byName = {for (final r in results) r.sheetName: r};

    expect(byName['2024']!.rows, hasLength(1));

    expect(byName['Summary']!.rows, isEmpty);
    expect(
      byName['Summary']!.issues.single.severity,
      ImportIssueSeverity.warning,
    );
    expect(
      byName['Summary']!.issues.single.message,
      contains('non-year sheet'),
    );

    expect(byName['Notes']!.rows, isEmpty);
  });

  test('re-importing identical bytes yields identical results (determinism)', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 3, 15),
          'counts': {2: 1, 6: 2},
        },
        {
          'date': DateTime(2024, 3, 16),
          'counts': <int, int>{},
        },
      ],
    });

    final first = parser.parse(bytes);
    final second = XlsxParser().parse(bytes);

    expect(first.length, second.length);
    for (var i = 0; i < first.length; i++) {
      expect(first[i].sheetName, second[i].sheetName);
      expect(first[i].rows.length, second[i].rows.length);
      for (var r = 0; r < first[i].rows.length; r++) {
        expect(first[i].rows[r].date, second[i].rows[r].date);
        expect(first[i].rows[r].typeCounts, second[i].rows[r].typeCounts);
      }
      expect(first[i].issues.length, second[i].issues.length);
    }
  });

  test('multiple year sheets in one workbook parse independently', () {
    final bytes = SpreadsheetFixture.createXlsx({
      '2024': [
        {
          'date': DateTime(2024, 1, 1),
          'counts': {1: 1},
        },
      ],
      '2025': [
        {
          'date': DateTime(2025, 6, 1),
          'counts': {7: 2},
        },
      ],
    });

    final results = parser.parse(bytes);
    final byName = {for (final r in results) r.sheetName: r};

    expect(byName.keys, containsAll(['2024', '2025']));
    expect(byName['2024']!.rows.single.date, DateTime(2024, 1, 1));
    expect(byName['2025']!.rows.single.date, DateTime(2025, 6, 1));
  });
}
