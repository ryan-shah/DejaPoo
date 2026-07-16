import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Drift-backed implementation of [BowelMovementRepository].
///
/// Datetime conventions (see designs/PHASE_1 docs): `occurredAt` is stored as
/// local wall time so SQL `date(occurred_at)` groups by the user's calendar
/// day; `createdAt`/`updatedAt`/`deletedAt` are stored as UTC instants.
class DriftBowelMovementRepository implements BowelMovementRepository {
  DriftBowelMovementRepository(
    this._db, {
    DateTime Function()? clock,
    this._uuid = const Uuid(),
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  $BowelMovementsTable get _table => _db.bowelMovements;

  @override
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
  }) async {
    final DateTime now = _clock().toUtc();
    final BowelMovement movement = BowelMovement(
      id: _uuid.v4(),
      occurredAt: occurredAt.toLocal(),
      dateOnly: dateOnly,
      bristolType: bristolType,
      size: size,
      color: color,
      urgency: urgency,
      strain: strain,
      blood: blood,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_table).insert(movement.toInsertable());
    return movement;
  }

  @override
  Future<void> insertAll(List<BowelMovement> movements) async {
    await _db.batch((Batch batch) {
      batch.insertAll(
        _table,
        movements.map((BowelMovement m) => m.toInsertable()),
      );
    });
  }

  @override
  Future<BowelMovement> update(BowelMovement movement) async {
    final BowelMovement updated = movement.copyWith(
      occurredAt: movement.occurredAt.toLocal(),
      updatedAt: _clock().toUtc(),
    );
    await _db.update(_table).replace(updated.toInsertable());
    return updated;
  }

  @override
  Future<void> softDelete(String id) async {
    final DateTime now = _clock().toUtc();
    await (_db.update(_table)..where(($BowelMovementsTable t) => t.id.equals(id))).write(
      BowelMovementsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<BowelMovement?> getById(String id) {
    final SimpleSelectStatement<$BowelMovementsTable, BowelMovement> query =
        _db.select(_table)
          ..where(
            ($BowelMovementsTable t) => t.id.equals(id) & t.deletedAt.isNull(),
          );
    return query.getSingleOrNull();
  }

  @override
  Future<List<BowelMovement>> getRange(DateTime from, DateTime to) {
    return _rangeQuery(from, to).get();
  }

  @override
  Stream<List<BowelMovement>> watchRange(DateTime from, DateTime to) {
    return _rangeQuery(from, to).watch();
  }

  SimpleSelectStatement<$BowelMovementsTable, BowelMovement> _rangeQuery(
    DateTime from,
    DateTime to,
  ) {
    return _db.select(_table)
      ..where(
        ($BowelMovementsTable t) =>
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(from.toLocal()) &
            t.occurredAt.isSmallerThanValue(to.toLocal()),
      )
      ..orderBy(<OrderClauseGenerator<$BowelMovementsTable>>[
        ($BowelMovementsTable t) =>
            OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
      ]);
  }
}
