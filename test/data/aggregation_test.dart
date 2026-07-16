import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/fixtures/fixture_generator.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

BowelMovement _bm(
  String id,
  DateTime occurredAt,
  BristolType type, {
  bool dateOnly = false,
  DateTime? deletedAt,
}) {
  final DateTime touched = DateTime.utc(2026, 1, 1);
  return BowelMovement(
    id: id,
    occurredAt: occurredAt,
    dateOnly: dateOnly,
    bristolType: type,
    createdAt: touched,
    updatedAt: touched,
    deletedAt: deletedAt,
  );
}

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);

    // Hand-crafted July 2026 scenario. Range under test: [07-01, 07-10].
    //   06-30 23:00  type2                (before range)
    //   07-01 00:00  type3                (midnight boundary, in range)
    //   07-01 20:00  type4
    //   07-02 12:00  type4 (dateOnly)     (counts toward daily stats)
    //   07-03 10:00  type2 SOFT-DELETED   (must never appear)
    //   07-05        type1 x2, type7
    //   07-10 23:59  type5                (end boundary, in range)
    //   07-11 09:00  type6                (after range; feeds currentStreak)
    await repo.insertAll(<BowelMovement>[
      _bm('before', DateTime(2026, 6, 30, 23), BristolType.type2),
      _bm('a', DateTime(2026, 7, 1), BristolType.type3),
      _bm('b', DateTime(2026, 7, 1, 20), BristolType.type4),
      _bm('c', DateTime(2026, 7, 2, 12), BristolType.type4, dateOnly: true),
      _bm(
        'deleted',
        DateTime(2026, 7, 3, 10),
        BristolType.type2,
        deletedAt: DateTime.utc(2026, 7, 3, 11),
      ),
      _bm('d', DateTime(2026, 7, 5, 7), BristolType.type1),
      _bm('e', DateTime(2026, 7, 5, 9), BristolType.type1),
      _bm('f', DateTime(2026, 7, 5, 22), BristolType.type7),
      _bm('g', DateTime(2026, 7, 10, 23, 59, 59), BristolType.type5),
      _bm('after', DateTime(2026, 7, 11, 9), BristolType.type6),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  final DateTime firstDay = DateTime(2026, 7, 1);
  final DateTime lastDay = DateTime(2026, 7, 10);

  test('dailyTypeCounts returns per-day per-type counts, ordered', () async {
    expect(await repo.dailyTypeCounts(firstDay, lastDay), <DailyTypeCount>[
      DailyTypeCount(day: DateTime(2026, 7, 1), type: BristolType.type3, count: 1),
      DailyTypeCount(day: DateTime(2026, 7, 1), type: BristolType.type4, count: 1),
      DailyTypeCount(day: DateTime(2026, 7, 2), type: BristolType.type4, count: 1),
      DailyTypeCount(day: DateTime(2026, 7, 5), type: BristolType.type1, count: 2),
      DailyTypeCount(day: DateTime(2026, 7, 5), type: BristolType.type7, count: 1),
      DailyTypeCount(day: DateTime(2026, 7, 10), type: BristolType.type5, count: 1),
    ]);
  });

  test('typeDistribution sums per type over the range', () async {
    expect(await repo.typeDistribution(firstDay, lastDay), <BristolType, int>{
      BristolType.type1: 2,
      BristolType.type3: 1,
      BristolType.type4: 2,
      BristolType.type5: 1,
      BristolType.type7: 1,
    });
  });

  test('totalCount and averagePerDay cover the inclusive range', () async {
    expect(await repo.totalCount(firstDay, lastDay), 7);
    expect(await repo.averagePerDay(firstDay, lastDay), closeTo(0.7, 1e-9));
  });

  test('longestGapDays finds the widest zero-event run between events',
      () async {
    // Event days 1, 2, 5, 10 → gaps of 2 (days 3-4) and 4 (days 6-9).
    expect(await repo.longestGapDays(firstDay, lastDay), 4);
  });

  test('longestStreakDays finds consecutive event days', () async {
    // Event days 1, 2, 5, 10 → longest streak is days 1-2.
    expect(await repo.longestStreakDays(firstDay, lastDay), 2);
  });

  test('currentStreakDays walks back over all history', () async {
    // 07-10 and 07-11 both have events; 07-09 does not.
    expect(await repo.currentStreakDays(DateTime(2026, 7, 11)), 2);
    expect(await repo.currentStreakDays(DateTime(2026, 7, 10)), 1);
    // Grace day: 07-12 has no events, so count the streak ending 07-11.
    expect(await repo.currentStreakDays(DateTime(2026, 7, 12)), 2);
    // 07-13: neither 07-13 nor 07-12 has events.
    expect(await repo.currentStreakDays(DateTime(2026, 7, 13)), 0);
  });

  test('an empty sub-range yields zeros and hides soft-deleted rows',
      () async {
    // 07-03 only contains the soft-deleted row; 07-04 has nothing.
    final DateTime from = DateTime(2026, 7, 3);
    final DateTime to = DateTime(2026, 7, 4);
    expect(await repo.dailyTypeCounts(from, to), isEmpty);
    expect(await repo.typeDistribution(from, to), isEmpty);
    expect(await repo.totalCount(from, to), 0);
    expect(await repo.averagePerDay(from, to), 0);
    expect(await repo.longestGapDays(from, to), 0);
    expect(await repo.longestStreakDays(from, to), 0);
  });

  test('fixture-generated data reconciles across aggregation views', () async {
    final List<BowelMovement> fixtures = FixtureGenerator(seed: 99).generate(
      firstDay: DateTime(2025),
      lastDay: DateTime(2025, 12, 31),
    );
    final AppDatabase fixtureDb = AppDatabase(NativeDatabase.memory());
    final DriftBowelMovementRepository fixtureRepo =
        DriftBowelMovementRepository(fixtureDb);
    addTearDown(fixtureDb.close);
    await fixtureRepo.insertAll(fixtures);

    final DateTime first = DateTime(2025);
    final DateTime last = DateTime(2025, 12, 31);

    expect(await fixtureRepo.totalCount(first, last), fixtures.length);

    final List<DailyTypeCount> daily =
        await fixtureRepo.dailyTypeCounts(first, last);
    final int dailySum =
        daily.fold(0, (int sum, DailyTypeCount d) => sum + d.count);
    expect(dailySum, fixtures.length);

    final Map<BristolType, int> distribution =
        await fixtureRepo.typeDistribution(first, last);
    final int distributionSum =
        distribution.values.fold(0, (int sum, int c) => sum + c);
    expect(distributionSum, fixtures.length);

    final List<PeriodTypeCount> monthly = rollUpByMonth(daily);
    final int monthlySum =
        monthly.fold(0, (int sum, PeriodTypeCount p) => sum + p.count);
    expect(monthlySum, fixtures.length);

    expect(
      await fixtureRepo.averagePerDay(first, last),
      closeTo(fixtures.length / 365, 1e-9),
    );
  });
}
