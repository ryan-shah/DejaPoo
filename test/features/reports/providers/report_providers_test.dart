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

  group('selectedReportRange', () {
    test('defaults to the current calendar month', () {
      final ReportRange range = container.read(selectedReportRangeProvider);
      final ReportRange expected = ReportRange.month(anchor: DateTime.now());
      expect(range, expected);
    });

    test('setRange replaces the range', () {
      final ReportRange target = ReportRange.year(anchor: DateTime(2026, 1, 1));
      container.read(selectedReportRangeProvider.notifier).setRange(target);
      expect(container.read(selectedReportRangeProvider), target);
    });

    test('next and previous step the range', () {
      final ReportRange start = ReportRange.month(anchor: DateTime(2026, 7, 1));
      container.read(selectedReportRangeProvider.notifier).setRange(start);

      container.read(selectedReportRangeProvider.notifier).next();
      expect(
        container.read(selectedReportRangeProvider),
        ReportRange.month(anchor: DateTime(2026, 8, 1)),
      );

      container.read(selectedReportRangeProvider.notifier).previous();
      container.read(selectedReportRangeProvider.notifier).previous();
      expect(
        container.read(selectedReportRangeProvider),
        ReportRange.month(anchor: DateTime(2026, 6, 1)),
      );
    });
  });

  group('reportEntries', () {
    test('watches only entries within the selected range', () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.month(anchor: DateTime(2026, 7, 1)));

      await repo.create(
        occurredAt: DateTime(2026, 7, 15, 9),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 6, 30, 23, 59),
        bristolType: BristolType.type3,
      );
      await repo.create(
        occurredAt: DateTime(2026, 8, 1),
        bristolType: BristolType.type5,
      );

      // Keep the provider alive while awaiting its future, otherwise it can
      // be disposed mid-load (no active listener).
      final ProviderSubscription<AsyncValue<List<BowelMovement>>>
          subscription = container.listen(reportEntriesProvider, (_, _) {});
      final List<BowelMovement> entries =
          await container.read(reportEntriesProvider.future);
      expect(entries.length, 1);
      expect(entries.single.bristolType, BristolType.type4);
      subscription.close();
    });

    test('inserting a new entry triggers a stream update', () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.month(anchor: DateTime(2026, 7, 1)));

      final List<List<BowelMovement>> emissions = <List<BowelMovement>>[];
      final ProviderSubscription<AsyncValue<List<BowelMovement>>>
          subscription = container.listen(
        reportEntriesProvider,
        (AsyncValue<List<BowelMovement>>? previous,
            AsyncValue<List<BowelMovement>> next) {
          final List<BowelMovement>? value = next.value;
          if (value != null) {
            emissions.add(value);
          }
        },
        fireImmediately: true,
      );

      // Let the initial (empty) emission land.
      await Future<void>.delayed(Duration.zero);
      expect(emissions.last, isEmpty);

      await repo.create(
        occurredAt: DateTime(2026, 7, 10),
        bristolType: BristolType.type6,
      );
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.length, 1);
      subscription.close();
    });
  });

  group('reportStats', () {
    test('computes total, average, mostCommonType, healthyPercentage, gaps',
        () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.custom(
            from: DateTime(2026, 7, 1),
            to: DateTime(2026, 7, 10),
          )); // 10 days

      // Day 1: two type4 (healthy)
      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 20),
        bristolType: BristolType.type4,
      );
      // Day 5: one type4 (healthy)
      await repo.create(
        occurredAt: DateTime(2026, 7, 5, 8),
        bristolType: BristolType.type4,
      );
      // Day 10: one type7 (unhealthy)
      await repo.create(
        occurredAt: DateTime(2026, 7, 10, 8),
        bristolType: BristolType.type7,
      );

      final ReportStats stats =
          await container.read(reportStatsProvider.future);

      expect(stats.total, 4);
      expect(stats.averagePerDay, 4 / 10);
      expect(stats.mostCommonType, BristolType.type4);
      expect(stats.healthyPercentage, closeTo(75.0, 0.001)); // 3/4 healthy
      // Event days: 1, 5, 10. Gaps: (5-1-1)=3, (10-5-1)=4. Longest = 4.
      expect(stats.longestGapDays, 4);
    });

    test('empty range yields zeroed stats with null mostCommonType', () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.month(anchor: DateTime(2026, 7, 1)));

      final ReportStats stats =
          await container.read(reportStatsProvider.future);

      expect(stats.total, 0);
      expect(stats.averagePerDay, 0);
      expect(stats.mostCommonType, isNull);
      expect(stats.healthyPercentage, 0);
      expect(stats.longestGapDays, 0);
    });

    test('reportStats updates when a new entry is added', () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.month(anchor: DateTime(2026, 7, 1)));

      final ReportStats before =
          await container.read(reportStatsProvider.future);
      expect(before.total, 0);

      final List<AsyncValue<ReportStats>> emissions =
          <AsyncValue<ReportStats>>[];
      final ProviderSubscription<AsyncValue<ReportStats>> subscription =
          container.listen(
        reportStatsProvider,
        (AsyncValue<ReportStats>? previous, AsyncValue<ReportStats> next) {
          emissions.add(next);
        },
        fireImmediately: true,
      );

      await repo.create(
        occurredAt: DateTime(2026, 7, 15),
        bristolType: BristolType.type3,
      );
      await Future<void>.delayed(Duration.zero);

      final ReportStats after =
          await container.read(reportStatsProvider.future);
      expect(after.total, 1);
      subscription.close();
    });
  });

  group('reportTypeDistribution and reportDailyTypeCounts', () {
    test('reflect entries within the selected range', () async {
      container
          .read(selectedReportRangeProvider.notifier)
          .setRange(ReportRange.month(anchor: DateTime(2026, 7, 1)));

      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 1, 20),
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: DateTime(2026, 7, 2, 8),
        bristolType: BristolType.type5,
      );

      final Map<BristolType, int> distribution =
          await container.read(reportTypeDistributionProvider.future);
      expect(distribution[BristolType.type4], 2);
      expect(distribution[BristolType.type5], 1);

      final List<DailyTypeCount> daily =
          await container.read(reportDailyTypeCountsProvider.future);
      expect(daily.length, 2);
      expect(
        daily.where((DailyTypeCount d) => d.day == DateTime(2026, 7, 1)).single.count,
        2,
      );
    });
  });
}
