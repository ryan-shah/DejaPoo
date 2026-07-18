import 'dart:convert';
import 'dart:typed_data';

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/import_service.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spreadsheet_fixture.dart';

/// End-to-end tests: round-trip synthetic fixtures through the full import
/// pipeline (parse -> expand -> insertAllIfAbsent) and verify the reporting
/// layer (totalCount / typeDistribution / averagePerDay) sees exactly the
/// data that was imported.
void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late ImportService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(
      db,
      clock: () => DateTime.utc(2026, 7, 17, 12),
    );
    service = ImportService(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('e2e import round-trip', () {
    test('synthetic XLSX round-trip flows through reports', () async {
      final Uint8List bytes = SpreadsheetFixture.createXlsx(
        <String, List<Map<String, dynamic>>>{
          '2024': <Map<String, dynamic>>[
            <String, dynamic>{
              'date': DateTime(2024, 1, 1),
              'counts': <int, int>{1: 1, 3: 2},
            },
            <String, dynamic>{
              'date': DateTime(2024, 1, 2),
              'counts': <int, int>{4: 1},
            },
            <String, dynamic>{
              'date': DateTime(2024, 6, 15),
              'counts': <int, int>{7: 2},
            },
          ],
        },
      );

      final ImportSummary summary =
          await service.importBytes(bytes, 'export.xlsx');
      expect(summary.hasErrors, isFalse);
      expect(summary.insertedCount, 6); // 1+2 + 1 + 2

      final ReportRange range = ReportRange.year(anchor: DateTime(2024));
      final int total = await repo.totalCount(range.firstDay, range.lastDay);
      expect(total, 6);

      final Map<BristolType, int> dist =
          await repo.typeDistribution(range.firstDay, range.lastDay);
      expect(dist[BristolType.fromNumber(1)], 1);
      expect(dist[BristolType.fromNumber(3)], 2);
      expect(dist[BristolType.fromNumber(4)], 1);
      expect(dist[BristolType.fromNumber(7)], 2);

      final double avg =
          await repo.averagePerDay(range.firstDay, range.lastDay);
      expect(avg, closeTo(6 / 366, 1e-9)); // 2024 is a leap year
    });

    test('synthetic CSV round-trip flows through reports', () async {
      const String csvText = ''',DATE,TYPE 1,TYPE 2,TYPE 3,TYPE 4,TYPE 5,TYPE 6,TYPE 7,TOTAL
January,2024-01-01,1,,2,,,,,3
,2024-01-02,,,,1,,,,1
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvText));

      final ImportSummary summary =
          await service.importBytes(bytes, 'export.csv');
      expect(summary.hasErrors, isFalse);
      expect(summary.insertedCount, 4); // 1+2 + 1

      final ReportRange range = ReportRange.year(anchor: DateTime(2024));
      final int total = await repo.totalCount(range.firstDay, range.lastDay);
      expect(total, 4);

      final Map<BristolType, int> dist =
          await repo.typeDistribution(range.firstDay, range.lastDay);
      expect(dist[BristolType.fromNumber(1)], 1);
      expect(dist[BristolType.fromNumber(3)], 2);
      expect(dist[BristolType.fromNumber(4)], 1);
    });

    test('idempotent re-import inserts 0 the second time', () async {
      final Uint8List bytes = SpreadsheetFixture.createXlsx(
        <String, List<Map<String, dynamic>>>{
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
        },
      );

      final ImportSummary first =
          await service.importBytes(bytes, 'export.xlsx');
      expect(first.insertedCount, 4);

      final ImportSummary second =
          await service.importBytes(bytes, 'export.xlsx');
      expect(second.insertedCount, 0);
      expect(second.skippedCount, 4);

      final ReportRange range = ReportRange.year(anchor: DateTime(2024));
      final int total = await repo.totalCount(range.firstDay, range.lastDay);
      expect(total, 4);
    });

    test('multi-year XLSX keeps each year independently queryable', () async {
      final Uint8List bytes = SpreadsheetFixture.createXlsx(
        <String, List<Map<String, dynamic>>>{
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
          '2025': <Map<String, dynamic>>[
            <String, dynamic>{
              'date': DateTime(2025, 3, 5),
              'counts': <int, int>{2: 3},
            },
            <String, dynamic>{
              'date': DateTime(2025, 3, 6),
              'counts': <int, int>{5: 2, 6: 1},
            },
            <String, dynamic>{
              'date': DateTime(2025, 12, 31),
              'counts': <int, int>{1: 1},
            },
          ],
        },
      );

      final ImportSummary summary =
          await service.importBytes(bytes, 'export.xlsx');
      expect(summary.hasErrors, isFalse);
      expect(summary.insertedCount, 4 + 7); // 2024: 4, 2025: 3+3+1=7

      final ReportRange range2024 = ReportRange.year(anchor: DateTime(2024));
      final int total2024 =
          await repo.totalCount(range2024.firstDay, range2024.lastDay);
      expect(total2024, 4);

      final ReportRange range2025 = ReportRange.year(anchor: DateTime(2025));
      final int total2025 =
          await repo.totalCount(range2025.firstDay, range2025.lastDay);
      expect(total2025, 7);

      expect(summary.insertedCount, total2024 + total2025);
    });
  });
}
