import 'package:dejapoo/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekStart', () {
    test('maps any weekday to its Monday', () {
      // 2026-07-13 is a Monday.
      expect(weekStart(DateTime(2026, 7, 13)), DateTime(2026, 7, 13));
      expect(weekStart(DateTime(2026, 7, 15)), DateTime(2026, 7, 13));
      expect(weekStart(DateTime(2026, 7, 19)), DateTime(2026, 7, 13));
    });

    test('crosses month boundaries', () {
      // 2026-08-01 is a Saturday; its week starts Monday 2026-07-27.
      expect(weekStart(DateTime(2026, 8, 1)), DateTime(2026, 7, 27));
    });
  });

  group('rollUpByWeek', () {
    test('sums per type within ISO weeks, sorted by period then type', () {
      final List<DailyTypeCount> daily = <DailyTypeCount>[
        // Week of Mon 2026-07-06.
        DailyTypeCount(day: DateTime(2026, 7, 7), type: BristolType.type4, count: 2),
        DailyTypeCount(day: DateTime(2026, 7, 12), type: BristolType.type4, count: 1),
        DailyTypeCount(day: DateTime(2026, 7, 8), type: BristolType.type1, count: 1),
        // Week of Mon 2026-07-13.
        DailyTypeCount(day: DateTime(2026, 7, 13), type: BristolType.type4, count: 3),
      ];

      expect(rollUpByWeek(daily), <PeriodTypeCount>[
        PeriodTypeCount(
          periodStart: DateTime(2026, 7, 6),
          type: BristolType.type1,
          count: 1,
        ),
        PeriodTypeCount(
          periodStart: DateTime(2026, 7, 6),
          type: BristolType.type4,
          count: 3,
        ),
        PeriodTypeCount(
          periodStart: DateTime(2026, 7, 13),
          type: BristolType.type4,
          count: 3,
        ),
      ]);
    });
  });

  group('rollUpByMonth', () {
    test('sums per type within calendar months', () {
      final List<DailyTypeCount> daily = <DailyTypeCount>[
        DailyTypeCount(day: DateTime(2026, 6, 30), type: BristolType.type3, count: 1),
        DailyTypeCount(day: DateTime(2026, 7, 1), type: BristolType.type3, count: 2),
        DailyTypeCount(day: DateTime(2026, 7, 31), type: BristolType.type3, count: 1),
      ];

      expect(rollUpByMonth(daily), <PeriodTypeCount>[
        PeriodTypeCount(
          periodStart: DateTime(2026, 6),
          type: BristolType.type3,
          count: 1,
        ),
        PeriodTypeCount(
          periodStart: DateTime(2026, 7),
          type: BristolType.type3,
          count: 3,
        ),
      ]);
    });
  });

  group('longestStreak', () {
    test('is 0 for no days and 1 for a single day', () {
      expect(longestStreak(<DateTime>[]), 0);
      expect(longestStreak(<DateTime>[DateTime(2026, 7, 1)]), 1);
    });

    test('finds the longest consecutive run', () {
      expect(
        longestStreak(<DateTime>[
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 4),
          DateTime(2026, 7, 5),
          DateTime(2026, 7, 6),
          DateTime(2026, 7, 10),
        ]),
        3,
      );
    });

    test('ignores duplicate days and time components', () {
      expect(
        longestStreak(<DateTime>[
          DateTime(2026, 7, 1, 8),
          DateTime(2026, 7, 1, 20),
          DateTime(2026, 7, 2, 9),
        ]),
        2,
      );
    });
  });

  group('longestGap', () {
    test('is 0 with fewer than two event days', () {
      expect(longestGap(<DateTime>[]), 0);
      expect(longestGap(<DateTime>[DateTime(2026, 7, 1)]), 0);
    });

    test('is 0 for adjacent days', () {
      expect(
        longestGap(<DateTime>[DateTime(2026, 7, 1), DateTime(2026, 7, 2)]),
        0,
      );
    });

    test('counts zero-event days between event days', () {
      expect(
        longestGap(<DateTime>[
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 5),
          DateTime(2026, 7, 10),
        ]),
        4,
      );
    });
  });

  group('currentStreak', () {
    final List<DateTime> days = <DateTime>[
      DateTime(2026, 7, 8),
      DateTime(2026, 7, 9),
      DateTime(2026, 7, 10),
    ];

    test('counts back from today when today has events', () {
      expect(currentStreak(days, DateTime(2026, 7, 10)), 3);
    });

    test('grants a grace day when today has no events yet', () {
      expect(currentStreak(days, DateTime(2026, 7, 11)), 3);
    });

    test('is 0 when neither today nor yesterday has events', () {
      expect(currentStreak(days, DateTime(2026, 7, 13)), 0);
      expect(currentStreak(<DateTime>[], DateTime(2026, 7, 13)), 0);
    });
  });
}
