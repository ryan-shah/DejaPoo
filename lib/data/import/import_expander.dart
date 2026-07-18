import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';

/// Expands per-day Bristol-type counts into individual [BowelMovement]
/// entities with deterministic, collision-free ids.
///
/// Id format: `imp-<yyyy-MM-dd>-t<N>-<k>` where `N` is the Bristol type
/// number (1-7) and `k` is the 1-based occurrence index for that date+type.
class ImportExpander {
  /// Expands daily counts into individual BowelMovement entities.
  ///
  /// Merges duplicate dates first (summing counts, emitting warnings).
  /// Returns the expanded movements and any issues found.
  (List<BowelMovement>, List<ImportIssue>) expand(List<DailyCounts> rows) {
    final issues = <ImportIssue>[];

    // Merge duplicate dates, preserving first-seen order.
    final byDate = <String, DailyCounts>{};
    for (final row in rows) {
      final key = _dateKey(row.date);
      final existing = byDate[key];
      if (existing != null) {
        byDate[key] = existing.merge(row);
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.warning,
            message: 'Duplicate date $key — counts merged',
          ),
        );
      } else {
        byDate[key] = row;
      }
    }

    // Expand into BowelMovement entities, ordered by date.
    final sortedKeys = byDate.keys.toList()..sort();
    final movements = <BowelMovement>[];
    for (final key in sortedKeys) {
      final dc = byDate[key]!;
      final day = dc.date;
      // noon local time, matching FixtureGenerator's convention.
      final occurredAt = DateTime(day.year, day.month, day.day, 12);
      final touched = DateTime.utc(day.year, day.month, day.day, 12);

      for (int typeNum = 1; typeNum <= 7; typeNum++) {
        final count = dc.typeCounts[typeNum] ?? 0;
        for (int k = 1; k <= count; k++) {
          final id = 'imp-$key-t$typeNum-$k';
          movements.add(
            BowelMovement(
              id: id,
              occurredAt: occurredAt,
              dateOnly: true,
              bristolType: BristolType.fromNumber(typeNum),
              createdAt: touched,
              updatedAt: touched,
            ),
          );
        }
      }
    }

    return (movements, issues);
  }

  static String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
