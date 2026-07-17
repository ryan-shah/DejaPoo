// Phase 3 exit-criterion correctness gate (dp-85t.5): verifies that every
// ReportRange kind (Day/Week/Month/Year/Custom) and every ReportStats field
// renders exact expected numbers against fixture data, including the
// boundary cases called out in DESIGN.md (month-straddling weeks, 23:59
// local-time events, empty ranges, dateOnly events, most-common-type ties,
// and healthy-percentage rounding).
import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart' show bowelMovementRepositoryProvider;
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:dejapoo/features/reports/providers/report_providers.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);
    container = ProviderContainer(
      overrides: [
        bowelMovementRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ReportStats> statsFor(ReportRange range) async {
    container.read(selectedReportRangeProvider.notifier).setRange(range);
    return container.read(reportStatsProvider.future);
  }

  group('Day range', () {
    test('exact numbers for a single calendar day', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 8),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 12),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 20),
        bristolType: BristolType.type4,
      );
      // Different day, must be excluded.
      await repo.create(
        occurredAt: DateTime(2026, 7, 16, 8),
        bristolType: BristolType.type1,
      );

      final ReportRange range = ReportRange.day(anchor: DateTime(2026, 7, 15));
      expect(range.firstDay, range.lastDay);

      final ReportStats stats = await statsFor(range);
      expect(stats.total, 3);
      expect(stats.averagePerDay, 3.0);
      expect(stats.mostCommonType, BristolType.type4);
      expect(stats.healthyPercentage, 100.0);
      expect(stats.longestGapDays, 0);

      final Map<BristolType, int> distribution =
          await container.read(reportTypeDistributionProvider.future);
      expect(distribution[BristolType.type3], 1);
      expect(distribution[BristolType.type4], 2);
      expect(distribution.containsKey(BristolType.type1), isFalse);

      final List<DailyTypeCount> daily =
          await container.read(reportDailyTypeCountsProvider.future);
      expect(
        daily.every((DailyTypeCount d) => d.day == DateTime(2026, 7, 15)),
        isTrue,
      );
      expect(daily.fold<int>(0, (int a, DailyTypeCount d) => a + d.count), 3);
    });
  });

  group('Week range (straddles a month boundary)', () {
    test('exact numbers for Jun 29 - Jul 5 2026', () async {
      await repo.create(
        occurredAt: DateTime(2026, 6, 29, 9),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 6, 30, 9),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 9),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 5, 9),
        bristolType: BristolType.type5,
      );

      final ReportRange range =
          ReportRange.week(anchor: DateTime(2026, 6, 30));
      expect(range.firstDay, DateTime(2026, 6, 29));
      expect(range.lastDay, DateTime(2026, 7, 5));

      final ReportStats stats = await statsFor(range);
      expect(stats.total, 4);
      expect(stats.averagePerDay, closeTo(4 / 7, 0.0001));
      // All four types tie at count 1; SQL orders by bristol_type so the
      // lowest-numbered type (type1) is encountered first and wins the tie.
      expect(stats.mostCommonType, BristolType.type1);
      // Healthy = type3, type4, type5 = 3 of 4.
      expect(stats.healthyPercentage, closeTo(75.0, 0.0001));
      // Event days: Jun29, Jun30, Jul1, Jul5. Gaps: 0, 0, 3. Longest = 3.
      expect(stats.longestGapDays, 3);

      final List<DailyTypeCount> daily =
          await container.read(reportDailyTypeCountsProvider.future);
      final Set<DateTime> days = daily.map((DailyTypeCount d) => d.day).toSet();
      expect(days, containsAll(<DateTime>[
        DateTime(2026, 6, 29),
        DateTime(2026, 6, 30),
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 5),
      ]));
    });
  });

  group('Month range', () {
    test('exact numbers for July 2026 including 23:59 boundary and dateOnly',
        () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 9),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 9),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15),
        bristolType: BristolType.type6,
        dateOnly: true,
      );
      // Boundary: 23:59 on the last day of the month must stay on Jul 31,
      // not roll into August.
      await repo.create(
        occurredAt: DateTime(2026, 7, 31, 23, 59),
        bristolType: BristolType.type3,
      );

      final ReportRange range = ReportRange.month(anchor: DateTime(2026, 7, 1));
      expect(range.firstDay, DateTime(2026, 7, 1));
      expect(range.lastDay, DateTime(2026, 7, 31));

      final ReportStats stats = await statsFor(range);
      expect(stats.total, 4);
      expect(stats.averagePerDay, closeTo(4 / 31, 0.0001));
      expect(stats.mostCommonType, BristolType.type4);
      // Healthy = type3, type4 (x2) = 3 of 4.
      expect(stats.healthyPercentage, closeTo(75.0, 0.0001));
      // Event days: Jul1, Jul15, Jul31. Gaps: 13, 15. Longest = 15.
      expect(stats.longestGapDays, 15);

      final List<DailyTypeCount> daily =
          await container.read(reportDailyTypeCountsProvider.future);
      final DailyTypeCount jul31 = daily.singleWhere(
        (DailyTypeCount d) =>
            d.day == DateTime(2026, 7, 31) && d.type == BristolType.type3,
      );
      expect(jul31.count, 1);
      final DailyTypeCount jul15DateOnly = daily.singleWhere(
        (DailyTypeCount d) =>
            d.day == DateTime(2026, 7, 15) && d.type == BristolType.type6,
      );
      expect(jul15DateOnly.count, 1);
    });
  });

  group('Year range', () {
    test('exact numbers for calendar year 2026', () async {
      await repo.create(
        occurredAt: DateTime(2026, 1, 1, 9),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 3, 15, 9),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 10, 9),
        bristolType: BristolType.type5,
      );
      await repo.create(
        occurredAt: DateTime(2026, 12, 31, 9),
        bristolType: BristolType.type7,
      );

      final ReportRange range = ReportRange.year(anchor: DateTime(2026));
      expect(range.firstDay, DateTime(2026, 1, 1));
      expect(range.lastDay, DateTime(2026, 12, 31));

      final ReportStats stats = await statsFor(range);
      expect(stats.total, 4);
      expect(stats.averagePerDay, closeTo(4 / 365, 0.0001));
      // All four types tie at count 1; lowest-numbered type wins.
      expect(stats.mostCommonType, BristolType.type1);
      // Healthy = type4, type5 = 2 of 4.
      expect(stats.healthyPercentage, closeTo(50.0, 0.0001));
      // Event days: Jan1, Mar15, Jul10, Dec31. Gaps: 72, 116, 173. Max = 173.
      expect(stats.longestGapDays, 173);
    });
  });

  group('Custom range', () {
    test('exact numbers for an arbitrary 3-day span', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 10, 9),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 11, 9),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 12, 9),
        bristolType: BristolType.type5,
      );

      final ReportRange range = ReportRange.custom(
        from: DateTime(2026, 7, 10),
        to: DateTime(2026, 7, 12),
      );
      expect(range.firstDay, DateTime(2026, 7, 10));
      expect(range.lastDay, DateTime(2026, 7, 12));

      final ReportStats stats = await statsFor(range);
      expect(stats.total, 3);
      expect(stats.averagePerDay, 1.0);
      expect(stats.mostCommonType, BristolType.type3);
      expect(stats.healthyPercentage, 100.0);
      expect(stats.longestGapDays, 0);
    });
  });

  group('Boundary cases', () {
    test('empty range yields zeroed stats with null mostCommonType', () async {
      final ReportStats stats =
          await statsFor(ReportRange.month(anchor: DateTime(2026, 7, 1)));
      expect(stats.total, 0);
      expect(stats.averagePerDay, 0);
      expect(stats.mostCommonType, isNull);
      expect(stats.healthyPercentage, 0);
      expect(stats.longestGapDays, 0);
    });

    test('a 23:59:59 local-time event stays on its own calendar day',
        () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 23, 59, 59),
        bristolType: BristolType.type4,
      );

      final ReportStats sameDay =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(sameDay.total, 1);

      final ReportStats nextDay =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 16)));
      expect(nextDay.total, 0);
    });

    test('dateOnly events are counted in totals and type distribution',
        () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15),
        bristolType: BristolType.type5,
        dateOnly: true,
      );

      final ReportStats stats =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(stats.total, 1);

      final Map<BristolType, int> distribution =
          await container.read(reportTypeDistributionProvider.future);
      expect(distribution[BristolType.type5], 1);
    });

    test('most-common-type tie resolves to the lowest type number', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 8),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 12),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 20),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 22),
        bristolType: BristolType.type3,
      );

      final ReportStats stats =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(stats.total, 4);
      expect(stats.mostCommonType, BristolType.type1);
    });

    test('healthy percentage: 0% when no movements are healthy', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 8),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 12),
        bristolType: BristolType.type7,
      );

      final ReportStats stats =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(stats.healthyPercentage, 0.0);
    });

    test('healthy percentage: 100% when every movement is healthy', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 8),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 12),
        bristolType: BristolType.type4,
      );

      final ReportStats stats =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(stats.healthyPercentage, 100.0);
    });

    test('healthy percentage: fractional rounding for 1 of 3', () async {
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 8),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 12),
        bristolType: BristolType.type1,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 20),
        bristolType: BristolType.type2,
      );

      final ReportStats stats =
          await statsFor(ReportRange.day(anchor: DateTime(2026, 7, 15)));
      expect(stats.total, 3);
      expect(stats.healthyPercentage, closeTo(33.333, 0.01));
    });
  });
}
