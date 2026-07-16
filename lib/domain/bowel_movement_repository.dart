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
}
