import 'dart:convert';
import 'dart:typed_data';

import 'package:dejapoo/data/import/csv_parser.dart';
import 'package:dejapoo/data/import/import_expander.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/xlsx_parser.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bowel_movement_repository.dart';

/// Parses a spreadsheet (XLSX or CSV) and persists the resulting events,
/// skipping any that already exist (idempotent re-import).
///
/// Dispatch between formats is based on file extension, with a magic-bytes
/// fallback (`PK\x03\x04`, the zip signature XLSX files start with) so a
/// mislabeled `.csv` containing XLSX bytes still parses correctly.
class ImportService {
  ImportService(this._repo);

  final BowelMovementRepository _repo;

  /// Zip local-file-header signature: XLSX files are zip archives.
  static const List<int> _zipMagic = <int>[0x50, 0x4B, 0x03, 0x04];

  Future<ImportSummary> importBytes(Uint8List bytes, String filename) async {
    try {
      final List<DailyCounts> allRows = <DailyCounts>[];
      final List<ImportIssue> issues = <ImportIssue>[];

      if (_isXlsx(bytes, filename)) {
        final List<SheetParseResult> results = XlsxParser().parse(bytes);
        for (final SheetParseResult result in results) {
          allRows.addAll(result.rows);
          issues.addAll(result.issues);
        }
      } else {
        final SheetParseResult result = CsvParser().parse(utf8.decode(bytes));
        allRows.addAll(result.rows);
        issues.addAll(result.issues);
      }

      final (List<BowelMovement> movements, List<ImportIssue> expandIssues) =
          ImportExpander().expand(allRows);
      issues.addAll(expandIssues);

      final int inserted = await _repo.insertAllIfAbsent(movements);
      final int skipped = movements.length - inserted;

      return ImportSummary(
        insertedCount: inserted,
        skippedCount: skipped,
        issues: issues,
      );
    } catch (e) {
      return ImportSummary(
        insertedCount: 0,
        skippedCount: 0,
        issues: <ImportIssue>[
          ImportIssue(
            severity: ImportIssueSeverity.error,
            message: 'Import failed: $e',
          ),
        ],
      );
    }
  }

  bool _isXlsx(Uint8List bytes, String filename) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return true;
    }
    if (lower.endsWith('.csv')) {
      // Still allow magic-byte override below.
    }
    if (bytes.length >= _zipMagic.length) {
      for (int i = 0; i < _zipMagic.length; i++) {
        if (bytes[i] != _zipMagic[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
}
