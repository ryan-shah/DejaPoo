import 'package:dejapoo/domain/domain.dart';
import 'package:drift/drift.dart';

/// Maps [BristolType] to its chart number (1-7) in the database, matching the
/// data model in designs/DESIGN.md (not the enum index).
class BristolTypeConverter extends TypeConverter<BristolType, int> {
  const BristolTypeConverter();

  @override
  BristolType fromSql(int fromDb) => BristolType.fromNumber(fromDb);

  @override
  int toSql(BristolType value) => value.number;
}

/// Drift table for [BowelMovement] rows.
///
/// Rows are soft-deleted (non-null [deletedAt]) so Phase 5 sync can merge
/// tombstones; every query must filter `deleted_at IS NULL`.
@TableIndex(name: 'idx_bowel_movements_occurred_at', columns: {#occurredAt})
@TableIndex(name: 'idx_bowel_movements_deleted_at', columns: {#deletedAt})
@UseRowClass(BowelMovement, generateInsertable: true)
class BowelMovements extends Table {
  TextColumn get id => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get dateOnly => boolean().withDefault(const Constant(false))();
  IntColumn get bristolType => integer().map(const BristolTypeConverter())();
  IntColumn get size => intEnum<StoolSize>().nullable()();
  IntColumn get color => intEnum<StoolColor>().nullable()();
  IntColumn get urgency => integer().nullable()();
  IntColumn get strain => integer().nullable()();
  BoolColumn get blood => boolean().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
