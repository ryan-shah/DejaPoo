import 'package:dejapoo/domain/aggregates.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/stool_color.dart';
import 'package:dejapoo/domain/stool_size.dart';

/// Persistence boundary for [BowelMovement] records.
///
/// All read methods exclude soft-deleted rows. Deletes are soft (tombstones
/// with `deletedAt`) so Phase 5 sync can merge them.
abstract class BowelMovementRepository {
  /// Creates and persists a new movement, assigning its id and timestamps.
  /// Returns the stored entity.
  Future<BowelMovement> create({
    required DateTime occurredAt,
    required BristolType bristolType,
    bool dateOnly = false,
    StoolSize? size,
    StoolColor? color,
    int? urgency,
    int? strain,
    bool? blood,
    String? note,
  });

  /// Bulk-inserts fully formed entities (fixture seeding, historical import).
  Future<void> insertAll(List<BowelMovement> movements);

  /// Persists changes to an existing movement, bumping `updatedAt`.
  /// Returns the stored entity.
  Future<BowelMovement> update(BowelMovement movement);

  /// Soft-deletes the movement with [id] by setting its `deletedAt`
  /// tombstone (also bumps `updatedAt` for sync).
  Future<void> softDelete(String id);

  /// The movement with [id], or null if unknown or soft-deleted.
  Future<BowelMovement?> getById(String id);

  /// Movements with `occurredAt` in `[from, to)`, newest first.
  Future<List<BowelMovement>> getRange(DateTime from, DateTime to);

  /// Watches movements with `occurredAt` in `[from, to)`, newest first.
  Stream<List<BowelMovement>> watchRange(DateTime from, DateTime to);

  // Aggregations. Ranges are calendar-day based and inclusive on both ends;
  // only the date components of [firstDay]/[lastDay] are used. Weekly and
  // monthly figures are rollups of the daily counts (see rollUpByWeek /
  // rollUpByMonth in aggregates.dart).

  /// Per-day, per-type counts for days in `[firstDay, lastDay]`, ordered by
  /// day then type. Days without events are absent.
  Future<List<DailyTypeCount>> dailyTypeCounts(
    DateTime firstDay,
    DateTime lastDay,
  );

  /// Total events per type over `[firstDay, lastDay]`. Types without events
  /// are absent.
  Future<Map<BristolType, int>> typeDistribution(
    DateTime firstDay,
    DateTime lastDay,
  );

  /// Total event count over `[firstDay, lastDay]`.
  Future<int> totalCount(DateTime firstDay, DateTime lastDay);

  /// [totalCount] divided by the number of days in `[firstDay, lastDay]`.
  Future<double> averagePerDay(DateTime firstDay, DateTime lastDay);

  /// Longest run of consecutive zero-event days strictly between two event
  /// days within `[firstDay, lastDay]`; 0 with fewer than two event days.
  Future<int> longestGapDays(DateTime firstDay, DateTime lastDay);

  /// Longest run of consecutive days with at least one event within
  /// `[firstDay, lastDay]`.
  Future<int> longestStreakDays(DateTime firstDay, DateTime lastDay);

  /// Consecutive event days ending at [today] (or yesterday, if [today] has
  /// no events yet), looking back over all history.
  Future<int> currentStreakDays(DateTime today);

  /// Hard-deletes every row in the table (demo/fixture teardown only).
  Future<void> deleteAll();
}
