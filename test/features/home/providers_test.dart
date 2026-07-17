import 'dart:collection';

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/providers/timeline_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a [BowelMovement] with minimal required fields for testing.
BowelMovement _entry(
  String id,
  DateTime occurredAt,
  BristolType type,
) {
  return BowelMovement(
    id: id,
    occurredAt: occurredAt,
    dateOnly: false,
    bristolType: type,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('groupEntriesByDay', () {
    test('groups entries by local calendar day with keys newest-first', () {
      final List<BowelMovement> entries = <BowelMovement>[
        _entry('d', DateTime(2026, 7, 16, 7, 0), BristolType.type5),
        _entry('b', DateTime(2026, 7, 15, 20, 0), BristolType.type3),
        _entry('a', DateTime(2026, 7, 15, 8, 0), BristolType.type4),
        _entry('c', DateTime(2026, 7, 14, 10, 0), BristolType.type2),
      ];

      final LinkedHashMap<DateTime, List<BowelMovement>> result =
          groupEntriesByDay(entries);

      final List<DateTime> keys = result.keys.toList();
      expect(keys, <DateTime>[
        DateTime(2026, 7, 16),
        DateTime(2026, 7, 15),
        DateTime(2026, 7, 14),
      ]);

      expect(result[DateTime(2026, 7, 16)]!.length, 1);
      expect(result[DateTime(2026, 7, 15)]!.length, 2);
      expect(result[DateTime(2026, 7, 14)]!.length, 1);
    });

    test('preserves within-day order from the input', () {
      final BowelMovement evening =
          _entry('b', DateTime(2026, 7, 15, 20, 0), BristolType.type3);
      final BowelMovement morning =
          _entry('a', DateTime(2026, 7, 15, 8, 0), BristolType.type4);

      // Input is newest-first (as the repository returns).
      final LinkedHashMap<DateTime, List<BowelMovement>> result =
          groupEntriesByDay(<BowelMovement>[evening, morning]);

      final List<BowelMovement> dayEntries = result[DateTime(2026, 7, 15)]!;
      expect(dayEntries.first.id, 'b');
      expect(dayEntries.last.id, 'a');
    });

    test('returns empty map for empty input', () {
      final LinkedHashMap<DateTime, List<BowelMovement>> result =
          groupEntriesByDay(<BowelMovement>[]);
      expect(result, isEmpty);
    });

    test('handles single entry', () {
      final LinkedHashMap<DateTime, List<BowelMovement>> result =
          groupEntriesByDay(<BowelMovement>[
        _entry('x', DateTime(2026, 7, 15, 12, 0), BristolType.type4),
      ]);

      expect(result.length, 1);
      expect(result.keys.first, DateTime(2026, 7, 15));
      expect(result.values.first.length, 1);
    });
  });

  group('TodaySummary', () {
    test('exposes count and byType', () {
      const TodaySummary summary = TodaySummary(
        count: 3,
        byType: <BristolType, int>{
          BristolType.type4: 2,
          BristolType.type3: 1,
        },
      );

      expect(summary.count, 3);
      expect(summary.byType[BristolType.type4], 2);
      expect(summary.byType[BristolType.type3], 1);
      expect(summary.byType[BristolType.type1], isNull);
    });

    test('equality', () {
      const TodaySummary a = TodaySummary(
        count: 2,
        byType: <BristolType, int>{BristolType.type4: 2},
      );
      const TodaySummary b = TodaySummary(
        count: 2,
        byType: <BristolType, int>{BristolType.type4: 2},
      );
      const TodaySummary c = TodaySummary(
        count: 1,
        byType: <BristolType, int>{BristolType.type4: 1},
      );

      expect(a, b);
      expect(a, isNot(c));
    });

    test('empty summary', () {
      const TodaySummary summary = TodaySummary(
        count: 0,
        byType: <BristolType, int>{},
      );

      expect(summary.count, 0);
      expect(summary.byType, isEmpty);
    });
  });

  group('provider integration', () {
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

    test('timelineProvider emits entries from the last 30 days', () async {
      final DateTime now = DateTime.now();
      final DateTime todayMorning =
          DateTime(now.year, now.month, now.day, 10, 0);

      await repo.create(
        occurredAt: todayMorning,
        bristolType: BristolType.type4,
      );

      container.listen(timelineProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final AsyncValue<List<BowelMovement>> value =
          container.read(timelineProvider);
      expect(value.value, isNotNull);
      expect(value.value!.length, 1);
      expect(value.value!.first.bristolType, BristolType.type4);
    });

    test('timelineProvider excludes entries older than 30 days', () async {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      // Entry 31 days ago should be excluded.
      await repo.create(
        occurredAt: today.subtract(const Duration(days: 31)),
        bristolType: BristolType.type2,
      );

      // Entry 29 days ago should be included.
      await repo.create(
        occurredAt: today.subtract(const Duration(days: 29)),
        bristolType: BristolType.type5,
      );

      container.listen(timelineProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final List<BowelMovement> entries =
          container.read(timelineProvider).value!;
      expect(entries.length, 1);
      expect(entries.first.bristolType, BristolType.type5);
    });

    test('todaySummaryProvider counts today entries by type', () async {
      final DateTime now = DateTime.now();
      final DateTime todayMorning =
          DateTime(now.year, now.month, now.day, 8, 0);
      final DateTime todayNoon =
          DateTime(now.year, now.month, now.day, 12, 0);

      await repo.create(
        occurredAt: todayMorning,
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: todayNoon,
        bristolType: BristolType.type4,
      );
      await repo.create(
        occurredAt: todayNoon,
        bristolType: BristolType.type3,
      );

      // Also insert a yesterday entry that should be excluded.
      await repo.create(
        occurredAt: DateTime(now.year, now.month, now.day - 1, 15, 0),
        bristolType: BristolType.type1,
      );

      container.listen(timelineProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final TodaySummary summary = container.read(todaySummaryProvider);
      expect(summary.count, 3);
      expect(summary.byType[BristolType.type4], 2);
      expect(summary.byType[BristolType.type3], 1);
      expect(summary.byType[BristolType.type1], isNull);
    });

    test('todaySummaryProvider returns empty when no entries today', () async {
      final DateTime now = DateTime.now();

      // Only a yesterday entry.
      await repo.create(
        occurredAt: DateTime(now.year, now.month, now.day - 1, 15, 0),
        bristolType: BristolType.type4,
      );

      container.listen(timelineProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final TodaySummary summary = container.read(todaySummaryProvider);
      expect(summary.count, 0);
      expect(summary.byType, isEmpty);
    });
  });
}
