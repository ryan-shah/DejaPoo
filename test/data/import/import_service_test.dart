import 'dart:convert';
import 'dart:typed_data';

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/import_service.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spreadsheet_fixture.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late ImportService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db, clock: () => DateTime.utc(2026, 7, 17, 12));
    service = ImportService(repo);
  });

  tearDown(() async {
    await db.close();
  });

  Uint8List xlsxBytes() {
    return SpreadsheetFixture.createXlsx(<String, List<Map<String, dynamic>>>{
      '2024': <Map<String, dynamic>>[
        <String, dynamic>{
          'date': DateTime(2024, 1, 1),
          'counts': <int, int>{1: 1, 3: 2},
        },
        <String, dynamic>{
          'date': DateTime(2024, 1, 2),
          'counts': <int, int>{4: 1},
        },
      ],
    });
  }

  const String csvText = ''',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL
January,2024-01-01,1,,2,,,,,3
,2024-01-02,,,,1,,,,1
''';

  group('ImportService.importBytes', () {
    test('imports XLSX bytes and inserts expanded events', () async {
      final ImportSummary summary =
          await service.importBytes(xlsxBytes(), 'export.xlsx');

      expect(summary.insertedCount, 4); // 1 + 2 + 1
      expect(summary.skippedCount, 0);
      expect(summary.hasErrors, isFalse);
    });

    test('imports CSV bytes and inserts expanded events', () async {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvText));
      final ImportSummary summary =
          await service.importBytes(bytes, 'export.csv');

      expect(summary.insertedCount, 4);
      expect(summary.skippedCount, 0);
      expect(summary.hasErrors, isFalse);
    });

    test('re-importing the same bytes skips all rows', () async {
      final Uint8List bytes = xlsxBytes();
      final ImportSummary first = await service.importBytes(bytes, 'export.xlsx');
      expect(first.insertedCount, 4);

      final ImportSummary second = await service.importBytes(bytes, 'export.xlsx');
      expect(second.insertedCount, 0);
      expect(second.skippedCount, 4);
    });

    test('garbage bytes produce an error issue without throwing', () async {
      final Uint8List garbage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

      final ImportSummary summary =
          await service.importBytes(garbage, 'export.xlsx');

      expect(summary.insertedCount, 0);
      expect(summary.skippedCount, 0);
      expect(summary.hasErrors, isTrue);
    });

    test('.csv extension with csv content parses as CSV', () async {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvText));
      final ImportSummary summary =
          await service.importBytes(bytes, 'data.csv');
      expect(summary.insertedCount, 4);
    });

    test('.xlsx extension with xlsx content parses as XLSX', () async {
      final ImportSummary summary =
          await service.importBytes(xlsxBytes(), 'data.xlsx');
      expect(summary.insertedCount, 4);
    });

    test('magic bytes dispatch XLSX content even with wrong extension', () async {
      // XLSX bytes but named .csv — should still be parsed as XLSX because
      // the zip magic bytes (PK\x03\x04) take precedence.
      final ImportSummary summary =
          await service.importBytes(xlsxBytes(), 'mislabeled.csv');
      expect(summary.insertedCount, 4);
      expect(summary.hasErrors, isFalse);
    });
  });
}
