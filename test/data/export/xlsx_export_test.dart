import 'package:dejapoo/data/export/xlsx_export.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

BowelMovement _mk({
  required String id,
  required DateTime occurredAt,
  required BristolType type,
  bool dateOnly = false,
}) {
  return BowelMovement(
    id: id,
    occurredAt: occurredAt,
    dateOnly: dateOnly,
    bristolType: type,
    createdAt: DateTime.utc(occurredAt.year, occurredAt.month, occurredAt.day),
    updatedAt: DateTime.utc(occurredAt.year, occurredAt.month, occurredAt.day),
  );
}

/// Extracts a numeric value from a cell, whether the `excel` package
/// surfaced it as [DoubleCellValue] or (for whole numbers) [IntCellValue].
double _numVal(CellValue? value) {
  if (value is DoubleCellValue) return value.value;
  if (value is IntCellValue) return value.value.toDouble();
  throw StateError('Expected a numeric cell value, got $value');
}

void main() {
  group('XlsxExport', () {
    test('empty list produces a valid, parseable XLSX with no year sheets', () {
      final bytes = XlsxExport.generate(const []);
      expect(bytes, isNotEmpty);
      final excel = Excel.decodeBytes(bytes);
      final yearSheets =
          excel.tables.keys.where((n) => RegExp(r'^\d{4}$').hasMatch(n));
      expect(yearSheets, isEmpty);
    });

    test('single day, single type produces one year sheet, one data row', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 3, 15, 10), type: BristolType.type4),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);

      expect(excel.tables.keys, contains('2024'));
      final sheet = excel.tables['2024']!;

      // Title row.
      expect(
        (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
                .value as TextCellValue)
            .value
            .text,
        'TYPES OF POOP',
      );

      // Header row.
      expect(
        (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
                .value as TextCellValue)
            .value
            .text,
        'MONTH',
      );

      // Data row (index 2).
      final monthCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      expect((monthCell.value as TextCellValue).value.text, 'March');

      final type4Cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2));
      expect(_numVal(type4Cell.value), 1.0);

      final totalCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2));
      expect(_numVal(totalCell.value), 1.0);

      // Only one data row.
      final nextRowDate =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3));
      expect(nextRowDate.value, isNull);
    });

    test('multiple days, multiple types produce correct counts per day', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 1, 5, 8), type: BristolType.type1),
        _mk(id: '2', occurredAt: DateTime(2024, 1, 5, 9), type: BristolType.type1),
        _mk(id: '3', occurredAt: DateTime(2024, 1, 5, 12), type: BristolType.type3),
        _mk(id: '4', occurredAt: DateTime(2024, 1, 7, 8), type: BristolType.type7),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['2024']!;

      // Row 2: Jan 5 -> type1 = 2, type3 = 1, total = 3.
      final type1Cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2));
      expect(_numVal(type1Cell.value), 2.0);
      final type3Cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2));
      expect(_numVal(type3Cell.value), 1.0);
      final total1 =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2));
      expect(_numVal(total1.value), 3.0);

      // Row 3: Jan 7 -> type7 = 1, total = 1.
      final type7Cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 3));
      expect(_numVal(type7Cell.value), 1.0);
      final total2 =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 3));
      expect(_numVal(total2.value), 1.0);
    });

    test('multiple years produce multiple sheets, named correctly', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2023, 6, 1, 8), type: BristolType.type4),
        _mk(id: '2', occurredAt: DateTime(2024, 6, 1, 8), type: BristolType.type4),
        _mk(id: '3', occurredAt: DateTime(2025, 6, 1, 8), type: BristolType.type4),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys.toSet(), {'2023', '2024', '2025'});
    });

    test('month names appear only on first occurrence per month', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 2, 1, 8), type: BristolType.type4),
        _mk(id: '2', occurredAt: DateTime(2024, 2, 5, 8), type: BristolType.type4),
        _mk(id: '3', occurredAt: DateTime(2024, 2, 10, 8), type: BristolType.type4),
        _mk(id: '4', occurredAt: DateTime(2024, 3, 1, 8), type: BristolType.type4),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['2024']!;

      // Row 2 (Feb 1): month written.
      expect(
        (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
                .value as TextCellValue)
            .value
            .text,
        'February',
      );
      // Row 3 (Feb 5): month blank.
      expect(
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
            .value,
        isNull,
      );
      // Row 4 (Feb 10): month blank.
      expect(
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
            .value,
        isNull,
      );
      // Row 5 (Mar 1): month written.
      expect(
        (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
                .value as TextCellValue)
            .value
            .text,
        'March',
      );
    });

    test('dateOnly and timed events on same day are summed', () {
      final movements = [
        _mk(
          id: '1',
          occurredAt: DateTime(2024, 4, 1, 12),
          type: BristolType.type5,
          dateOnly: true,
        ),
        _mk(
          id: '2',
          occurredAt: DateTime(2024, 4, 1, 18, 30),
          type: BristolType.type5,
        ),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['2024']!;

      final type5Cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 2));
      expect(_numVal(type5Cell.value), 2.0);
    });

    test('excludes soft-deleted movements', () {
      final active = _mk(
        id: '1',
        occurredAt: DateTime(2024, 5, 1, 8),
        type: BristolType.type4,
      );
      final deleted = active.copyWith(
        id: '2',
        deletedAt: DateTime.utc(2024, 5, 2),
      );
      final bytes = XlsxExport.generate([active, deleted]);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['2024']!;
      final total =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2));
      expect(_numVal(total.value), 1.0);
    });

    test('column J total matches sum of C-I', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 8, 9, 8), type: BristolType.type2),
        _mk(id: '2', occurredAt: DateTime(2024, 8, 9, 9), type: BristolType.type6),
        _mk(id: '3', occurredAt: DateTime(2024, 8, 9, 10), type: BristolType.type6),
        _mk(id: '4', occurredAt: DateTime(2024, 8, 9, 11), type: BristolType.type7),
      ];
      final bytes = XlsxExport.generate(movements);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['2024']!;

      var sum = 0.0;
      for (var col = 2; col <= 8; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2),
        );
        final v = cell.value;
        if (v != null) sum += _numVal(v);
      }
      final totalCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2));
      expect(_numVal(totalCell.value), sum);
      expect(sum, 4.0);
    });
  });
}
