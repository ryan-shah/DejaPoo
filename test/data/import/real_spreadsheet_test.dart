import 'dart:io';
import 'dart:typed_data';

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/import_service.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local-only gate test: imports the real "Alex Bowels.xlsx" historical
/// spreadsheet (gitignored, not present on CI) and asserts the exact
/// per-year totals from the Phase 4 exit criteria.
///
/// This file is a real regression gate for anyone with the source
/// spreadsheet on disk, but must never fail CI when the file is absent.
void main() {
  final File file = File('Alex Bowels.xlsx');

  if (!file.existsSync()) {
    test(
      'real spreadsheet gate (skipped — file not present)',
      () {},
      skip: 'Alex Bowels.xlsx not found in repo root',
    );
    return;
  }

  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late ImportService service;
  late Uint8List bytes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(
      db,
      clock: () => DateTime.utc(2026, 7, 17, 12),
    );
    service = ImportService(repo);
    bytes = Uint8List.fromList(file.readAsBytesSync());
  });

  tearDown(() async {
    await db.close();
  });

  group('real Alex Bowels.xlsx import gate', () {
    test('imports with no errors and matches known year totals', () async {
      final ImportSummary summary =
          await service.importBytes(bytes, 'Alex Bowels.xlsx');

      expect(summary.hasErrors, isFalse);
      expect(summary.insertedCount, 669 + 791 + 418);

      final ReportRange range2024 = ReportRange.year(anchor: DateTime(2024));
      final int count2024 =
          await repo.totalCount(range2024.firstDay, range2024.lastDay);
      expect(count2024, 669);

      final ReportRange range2025 = ReportRange.year(anchor: DateTime(2025));
      final int count2025 =
          await repo.totalCount(range2025.firstDay, range2025.lastDay);
      expect(count2025, 791);

      final ReportRange range2026 = ReportRange.year(anchor: DateTime(2026));
      final int count2026 =
          await repo.totalCount(range2026.firstDay, range2026.lastDay);
      expect(count2026, 418);
    });

    test('re-importing the same file is fully idempotent', () async {
      final ImportSummary first =
          await service.importBytes(bytes, 'Alex Bowels.xlsx');
      expect(first.insertedCount, 669 + 791 + 418);

      final ImportSummary second =
          await service.importBytes(bytes, 'Alex Bowels.xlsx');
      expect(second.insertedCount, 0);
      expect(second.skippedCount, 1878);
    });
  });
}
