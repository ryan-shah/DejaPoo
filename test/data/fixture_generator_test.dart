import 'package:dejapoo/data/fixtures/fixture_generator.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime firstDay = DateTime(2026);
  final DateTime lastDay = DateTime(2026, 12, 31);

  test('same seed produces identical output', () {
    final List<BowelMovement> a = FixtureGenerator(seed: 7)
        .generate(firstDay: firstDay, lastDay: lastDay);
    final List<BowelMovement> b = FixtureGenerator(seed: 7)
        .generate(firstDay: firstDay, lastDay: lastDay);
    expect(a, b);
  });

  test('different seeds produce different output', () {
    final List<BowelMovement> a = FixtureGenerator(seed: 1)
        .generate(firstDay: firstDay, lastDay: lastDay);
    final List<BowelMovement> b = FixtureGenerator(seed: 2)
        .generate(firstDay: firstDay, lastDay: lastDay);
    expect(a, isNot(b));
  });

  test('daily average lands near the requested rate', () {
    final List<BowelMovement> events = FixtureGenerator()
        .generate(firstDay: firstDay, lastDay: lastDay);
    // 365 days at 2.0/day: Poisson total has mean 730, sd ~27.
    expect(events.length, inInclusiveRange(600, 860));
  });

  test('all events fall within the requested range, in order', () {
    final List<BowelMovement> events = FixtureGenerator()
        .generate(firstDay: DateTime(2026, 3, 10), lastDay: DateTime(2026, 3, 20));
    final DateTime min = DateTime(2026, 3, 10);
    final DateTime max = DateTime(2026, 3, 21);
    for (final BowelMovement e in events) {
      expect(e.occurredAt.isBefore(min), isFalse);
      expect(e.occurredAt.isBefore(max), isTrue);
    }
    final List<BowelMovement> sorted = List<BowelMovement>.of(events)
      ..sort(
        (BowelMovement a, BowelMovement b) =>
            a.occurredAt.compareTo(b.occurredAt),
      );
    expect(events, sorted);
  });

  test('type distribution follows the default weights', () {
    final List<BowelMovement> events = FixtureGenerator()
        .generate(firstDay: DateTime(2024), lastDay: DateTime(2026, 12, 31));
    final Map<BristolType, int> counts = <BristolType, int>{};
    for (final BowelMovement e in events) {
      counts[e.bristolType] = (counts[e.bristolType] ?? 0) + 1;
    }
    // Type 4 (weight 0.30) should dominate type 7 (weight 0.04) by far.
    expect(counts[BristolType.type4], greaterThan(counts[BristolType.type7]! * 3));
    // Healthy range 3-5 carries ~73% of the weight; allow generous slack.
    final int healthy = (counts[BristolType.type3] ?? 0) +
        (counts[BristolType.type4] ?? 0) +
        (counts[BristolType.type5] ?? 0);
    expect(healthy / events.length, greaterThan(0.6));
  });

  test('dateOnly events carry the flag and a fixed noon time', () {
    final List<BowelMovement> events = FixtureGenerator().generate(
      firstDay: DateTime(2026, 5),
      lastDay: DateTime(2026, 5, 7),
      dateOnly: true,
    );
    expect(events, isNotEmpty);
    for (final BowelMovement e in events) {
      expect(e.dateOnly, isTrue);
      expect(e.occurredAt.hour, 12);
      expect(e.occurredAt.minute, 0);
    }
  });

  test('ids are unique across a generator instance', () {
    final FixtureGenerator generator = FixtureGenerator();
    final List<BowelMovement> events = <BowelMovement>[
      ...generator.generate(firstDay: DateTime(2026), lastDay: DateTime(2026, 1, 31)),
      ...generator.generate(firstDay: DateTime(2026, 2), lastDay: DateTime(2026, 2, 28)),
    ];
    expect(
      events.map((BowelMovement e) => e.id).toSet().length,
      events.length,
    );
  });
}
