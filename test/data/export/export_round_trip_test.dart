import 'package:dejapoo/data/export/csv_export.dart';
import 'package:dejapoo/data/export/xlsx_export.dart';
import 'package:dejapoo/data/import/csv_parser.dart';
import 'package:dejapoo/data/import/import_expander.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/import/xlsx_parser.dart';
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

/// Reduces a list of movements to per-day, per-type counts, matching the
/// shape [DailyCounts] uses, for comparison independent of event identity.
Map<String, Map<int, int>> _dailyTypeCounts(List<BowelMovement> movements) {
  final result = <String, Map<int, int>>{};
  for (final m in movements) {
    if (m.deletedAt != null) continue;
    final key = '${m.occurredAt.year.toString().padLeft(4, '0')}-'
        '${m.occurredAt.month.toString().padLeft(2, '0')}-'
        '${m.occurredAt.day.toString().padLeft(2, '0')}';
    final counts = result.putIfAbsent(key, () => {});
    final t = m.bristolType.number;
    counts[t] = (counts[t] ?? 0) + 1;
  }
  return result;
}

Map<String, Map<int, int>> _dailyCountsToMap(List<DailyCounts> rows) {
  final result = <String, Map<int, int>>{};
  for (final row in rows) {
    final key = '${row.date.year.toString().padLeft(4, '0')}-'
        '${row.date.month.toString().padLeft(2, '0')}-'
        '${row.date.day.toString().padLeft(2, '0')}';
    result[key] = Map<int, int>.from(row.typeCounts);
  }
  return result;
}

void main() {
  group('export -> import round trip', () {
    // A mix of timed and dateOnly events, multiple types, multiple days,
    // spanning two years, including a day with events summed across
    // multiple timed occurrences plus a dateOnly occurrence.
    final movements = [
      _mk(id: '1', occurredAt: DateTime(2023, 12, 31, 22), type: BristolType.type1),
      _mk(id: '2', occurredAt: DateTime(2024, 1, 1, 7, 15), type: BristolType.type4),
      _mk(id: '3', occurredAt: DateTime(2024, 1, 1, 20, 45), type: BristolType.type4),
      _mk(
        id: '4',
        occurredAt: DateTime(2024, 1, 1, 12),
        type: BristolType.type4,
        dateOnly: true,
      ),
      _mk(id: '5', occurredAt: DateTime(2024, 2, 14, 9), type: BristolType.type7),
      _mk(id: '6', occurredAt: DateTime(2024, 2, 14, 18), type: BristolType.type2),
      _mk(id: '7', occurredAt: DateTime(2025, 6, 3, 6), type: BristolType.type5),
      // Soft-deleted — must not appear on either side.
      _mk(
        id: '8',
        occurredAt: DateTime(2025, 6, 3, 10),
        type: BristolType.type5,
      ).copyWith(deletedAt: DateTime.utc(2025, 6, 4)),
    ];

    final expectedCounts = _dailyTypeCounts(movements);

    test('XLSX export -> XlsxParser -> ImportExpander preserves daily counts',
        () {
      final bytes = XlsxExport.generate(movements);
      final results = XlsxParser().parse(bytes);

      final allRows = <DailyCounts>[];
      for (final r in results) {
        allRows.addAll(r.rows);
      }

      final (expanded, _) = ImportExpander().expand(allRows);
      final actualCounts = _dailyTypeCounts(expanded);

      expect(actualCounts, expectedCounts);

      // Also verify at the raw DailyCounts level (pre-expansion).
      final rawCounts = _dailyCountsToMap(allRows);
      expect(rawCounts, expectedCounts);
    });

    test('CSV export -> CsvParser -> ImportExpander preserves daily counts',
        () {
      final csv = CsvExport.generate(movements);
      final result = CsvParser().parse(csv);

      final (expanded, _) = ImportExpander().expand(result.rows);
      final actualCounts = _dailyTypeCounts(expanded);

      expect(actualCounts, expectedCounts);

      final rawCounts = _dailyCountsToMap(result.rows);
      expect(rawCounts, expectedCounts);
    });

    test('expanded movements use deterministic imp- ids', () {
      final bytes = XlsxExport.generate(movements);
      final results = XlsxParser().parse(bytes);
      final allRows = <DailyCounts>[];
      for (final r in results) {
        allRows.addAll(r.rows);
      }
      final (expanded, _) = ImportExpander().expand(allRows);
      expect(expanded, isNotEmpty);
      for (final m in expanded) {
        expect(m.id, startsWith('imp-'));
      }
    });
  });
}
