import 'dart:typed_data';

import 'package:dejapoo/data/export/csv_export.dart';
import 'package:dejapoo/data/export/xlsx_export.dart';
import 'package:dejapoo/domain/domain.dart';

/// Orchestrates data export by fetching all movements from the repository
/// and delegating to format-specific generators.
class ExportService {
  ExportService(this._repository);

  final BowelMovementRepository _repository;

  /// Generates XLSX bytes of all non-deleted movements.
  Future<Uint8List> exportXlsx() async {
    final List<BowelMovement> all = await _repository.getAllIncludingDeleted();
    final List<BowelMovement> active =
        all.where((BowelMovement m) => m.deletedAt == null).toList();
    return XlsxExport.generate(active);
  }

  /// Generates CSV text of all non-deleted movements.
  Future<String> exportCsv() async {
    final List<BowelMovement> all = await _repository.getAllIncludingDeleted();
    final List<BowelMovement> active =
        all.where((BowelMovement m) => m.deletedAt == null).toList();
    return CsvExport.generate(active);
  }
}
