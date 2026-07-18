import 'package:csv/csv.dart';
import 'package:dejapoo/data/export/csv_export.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
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

void main() {
  group('CsvExport', () {
    test('empty list produces just the header row', () {
      final csv = CsvExport.generate(const []);
      final rows = Csv().decode(csv);
      expect(rows.length, 1);
      expect(rows[0], [
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
    });

    test('basic generation with correct column values', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 3, 15, 8), type: BristolType.type4),
        _mk(id: '2', occurredAt: DateTime(2024, 3, 15, 9), type: BristolType.type4),
      ];
      final csv = CsvExport.generate(movements);
      final rows = Csv().decode(csv);

      expect(rows.length, 2);
      final row = rows[1];
      expect(row[0], 'March');
      expect(row[1], '2024-03-15');
      // TYPE 4 is column index 5 (0=MONTH,1=DATE,2=T1,3=T2,4=T3,5=T4).
      expect(row[5].toString(), '2');
      // TOTAL is last column.
      expect(row[9].toString(), '2');
      // Other type columns blank.
      expect(row[2].toString(), '');
    });

    test('multiple days sorted chronologically', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 5, 20, 8), type: BristolType.type1),
        _mk(id: '2', occurredAt: DateTime(2024, 1, 3, 8), type: BristolType.type2),
        _mk(id: '3', occurredAt: DateTime(2024, 3, 11, 8), type: BristolType.type3),
      ];
      final csv = CsvExport.generate(movements);
      final rows = Csv().decode(csv);

      expect(rows.length, 4); // header + 3 data rows
      expect(rows[1][1], '2024-01-03');
      expect(rows[2][1], '2024-03-11');
      expect(rows[3][1], '2024-05-20');
    });

    test('month name only on first occurrence per month/year', () {
      final movements = [
        _mk(id: '1', occurredAt: DateTime(2024, 2, 1, 8), type: BristolType.type4),
        _mk(id: '2', occurredAt: DateTime(2024, 2, 5, 8), type: BristolType.type4),
      ];
      final csv = CsvExport.generate(movements);
      final rows = Csv().decode(csv);
      expect(rows[1][0], 'February');
      expect(rows[2][0], '');
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
      final csv = CsvExport.generate([active, deleted]);
      final rows = Csv().decode(csv);
      expect(rows.length, 2);
      expect(rows[1][9].toString(), '1');
    });
  });
}
