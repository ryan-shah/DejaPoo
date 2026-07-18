import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/db/bowel_movements_table.dart';
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
  Future<int> insertAllIfAbsent(List<BowelMovement> movements) async {
    if (movements.isEmpty) return 0;

    final List<String> allIds = <String>[
      for (final BowelMovement m in movements) m.id,
    ];
    final Set<String> existingIds = <String>{};

    // Chunk id lookups to stay under SQLite's bound-variable limit. Do NOT
    // filter on deletedAt here — soft-deleted rows must not be resurrected.
    for (int i = 0; i < allIds.length; i += 500) {
      final int end = (i + 500).clamp(0, allIds.length);
      final List<String> chunk = allIds.sublist(i, end);
      final List<BowelMovement> rows = await (_db.select(_table)
            ..where(($BowelMovementsTable t) => t.id.isIn(chunk)))
          .get();
      existingIds.addAll(rows.map((BowelMovement r) => r.id));
    }

    final List<BowelMovement> toInsert = movements
        .where((BowelMovement m) => !existingIds.contains(m.id))
        .toList();
    if (toInsert.isEmpty) return 0;

    await _db.batch((Batch batch) {
      batch.insertAll(
        _table,
        toInsert.map((BowelMovement m) => m.toInsertable()),
        mode: InsertMode.insertOrIgnore,
      );
    });

    return toInsert.length;
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
            t.occurredAt.isBiggerOrEqualValue(
              const LocalDateTimeConverter().toSql(from),
            ) &
            t.occurredAt.isSmallerThanValue(
              const LocalDateTimeConverter().toSql(to),
            ),
      )
      ..orderBy(<OrderClauseGenerator<$BowelMovementsTable>>[
        ($BowelMovementsTable t) =>
            OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
      ]);
  }

  @override
  Future<List<DailyTypeCount>> dailyTypeCounts(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT date(occurred_at) AS day, bristol_type AS type, '
      'COUNT(*) AS cnt '
      'FROM bowel_movements '
      'WHERE deleted_at IS NULL AND date(occurred_at) BETWEEN ? AND ? '
      'GROUP BY day, type '
      'ORDER BY day, type',
      variables: <Variable<Object>>[
        Variable<String>(_dayKey(firstDay)),
        Variable<String>(_dayKey(lastDay)),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_table},
    ).get();
    return <DailyTypeCount>[
      for (final QueryRow row in rows)
        DailyTypeCount(
          day: DateTime.parse(row.read<String>('day')),
          type: BristolType.fromNumber(row.read<int>('type')),
          count: row.read<int>('cnt'),
        ),
    ];
  }

  @override
  Future<Map<BristolType, int>> typeDistribution(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT bristol_type AS type, COUNT(*) AS cnt '
      'FROM bowel_movements '
      'WHERE deleted_at IS NULL AND date(occurred_at) BETWEEN ? AND ? '
      'GROUP BY type',
      variables: <Variable<Object>>[
        Variable<String>(_dayKey(firstDay)),
        Variable<String>(_dayKey(lastDay)),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_table},
    ).get();
    return <BristolType, int>{
      for (final QueryRow row in rows)
        BristolType.fromNumber(row.read<int>('type')): row.read<int>('cnt'),
    };
  }

  @override
  Future<int> totalCount(DateTime firstDay, DateTime lastDay) async {
    final QueryRow row = await _db.customSelect(
      'SELECT COUNT(*) AS cnt FROM bowel_movements '
      'WHERE deleted_at IS NULL AND date(occurred_at) BETWEEN ? AND ?',
      variables: <Variable<Object>>[
        Variable<String>(_dayKey(firstDay)),
        Variable<String>(_dayKey(lastDay)),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_table},
    ).getSingle();
    return row.read<int>('cnt');
  }

  @override
  Future<double> averagePerDay(DateTime firstDay, DateTime lastDay) async {
    final int days = DateTime.utc(lastDay.year, lastDay.month, lastDay.day)
            .difference(
              DateTime.utc(firstDay.year, firstDay.month, firstDay.day),
            )
            .inDays +
        1;
    if (days <= 0) {
      return 0;
    }
    return await totalCount(firstDay, lastDay) / days;
  }

  @override
  Future<int> longestGapDays(DateTime firstDay, DateTime lastDay) async {
    return longestGap(await _eventDays(firstDay, lastDay));
  }

  @override
  Future<int> longestStreakDays(DateTime firstDay, DateTime lastDay) async {
    return longestStreak(await _eventDays(firstDay, lastDay));
  }

  @override
  Future<int> currentStreakDays(DateTime today) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT DISTINCT date(occurred_at) AS day FROM bowel_movements '
      'WHERE deleted_at IS NULL AND date(occurred_at) <= ?',
      variables: <Variable<Object>>[Variable<String>(_dayKey(today))],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_table},
    ).get();
    return currentStreak(
      rows.map((QueryRow row) => DateTime.parse(row.read<String>('day'))),
      today,
    );
  }

  Future<List<DateTime>> _eventDays(DateTime firstDay, DateTime lastDay) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT DISTINCT date(occurred_at) AS day FROM bowel_movements '
      'WHERE deleted_at IS NULL AND date(occurred_at) BETWEEN ? AND ?',
      variables: <Variable<Object>>[
        Variable<String>(_dayKey(firstDay)),
        Variable<String>(_dayKey(lastDay)),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_table},
    ).get();
    return <DateTime>[
      for (final QueryRow row in rows)
        DateTime.parse(row.read<String>('day')),
    ];
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_table).go();
  }

  @override
  Future<List<BowelMovement>> getAllIncludingDeleted() {
    return _db.select(_table).get();
  }

  @override
  Future<void> applyRemote(List<BowelMovement> movements) async {
    if (movements.isEmpty) return;
    await _db.batch((Batch batch) {
      batch.insertAll(
        _table,
        movements.map((BowelMovement m) => m.toInsertable()),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  static String _dayKey(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }
}
