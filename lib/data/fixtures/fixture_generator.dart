import 'dart:math';

import 'package:dejapoo/domain/domain.dart';

/// Generates deterministic, synthetic [BowelMovement] fixtures shaped like
/// the real historical spreadsheet (roughly 1.8-2.2 events/day, dominated by
/// Bristol types 3-5).
///
/// Used by tests and (later) a debug seeding path. The output is purely
/// synthetic — never derived from the gitignored personal data.
class FixtureGenerator {
  FixtureGenerator({int seed = 42}) : _random = Random(seed);

  final Random _random;
  int _nextId = 0;

  /// Default per-type weights: healthy range (3-5) heavy, with tails.
  static const Map<BristolType, double> defaultTypeWeights =
      <BristolType, double>{
    BristolType.type1: 0.05,
    BristolType.type2: 0.10,
    BristolType.type3: 0.25,
    BristolType.type4: 0.30,
    BristolType.type5: 0.18,
    BristolType.type6: 0.08,
    BristolType.type7: 0.04,
  };

  /// Relative likelihood of an event starting in each hour of the day,
  /// weighted toward mornings the way real logs tend to be.
  static const List<double> _hourWeights = <double>[
    0.2, 0.1, 0.1, 0.1, 0.3, 0.8, // 00-05
    2.0, 3.0, 3.0, 2.5, 1.8, 1.2, // 06-11
    1.0, 1.0, 0.8, 0.8, 0.8, 1.0, // 12-17
    1.2, 1.2, 1.0, 0.8, 0.5, 0.3, // 18-23
  ];

  /// Generates events for every day from [firstDay] through [lastDay]
  /// (both inclusive, time-of-day components ignored), in chronological
  /// order. Daily counts are Poisson-distributed around [avgPerDay].
  ///
  /// [dateOnly] events get a fixed noon timestamp, mirroring how the
  /// spreadsheet importer will expand date-only counts.
  List<BowelMovement> generate({
    required DateTime firstDay,
    required DateTime lastDay,
    double avgPerDay = 2.0,
    Map<BristolType, double> typeWeights = defaultTypeWeights,
    bool dateOnly = false,
  }) {
    assert(avgPerDay > 0, 'avgPerDay must be positive');
    assert(typeWeights.isNotEmpty, 'typeWeights must not be empty');

    final DateTime start = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final DateTime end = DateTime(lastDay.year, lastDay.month, lastDay.day);
    assert(!end.isBefore(start), 'lastDay must not be before firstDay');

    final List<BowelMovement> events = <BowelMovement>[];
    for (DateTime day = start;
        !day.isAfter(end);
        day = DateTime(day.year, day.month, day.day + 1)) {
      final int count = _poisson(avgPerDay);
      final List<DateTime> times = List<DateTime>.generate(
        count,
        (_) => dateOnly ? day.add(const Duration(hours: 12)) : _timeOn(day),
      )..sort();
      for (final DateTime occurredAt in times) {
        final DateTime touched =
            DateTime.utc(day.year, day.month, day.day, 12);
        events.add(
          BowelMovement(
            id: 'fx-${_nextId++}',
            occurredAt: occurredAt,
            dateOnly: dateOnly,
            bristolType: _pickType(typeWeights),
            createdAt: touched,
            updatedAt: touched,
          ),
        );
      }
    }
    return events;
  }

  /// Draws from a Poisson distribution with mean [lambda] (Knuth's method).
  int _poisson(double lambda) {
    final double l = exp(-lambda);
    int k = 0;
    double p = 1;
    do {
      k++;
      p *= _random.nextDouble();
    } while (p > l);
    return k - 1;
  }

  DateTime _timeOn(DateTime day) {
    final int hour = _pickIndex(_hourWeights);
    return DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      _random.nextInt(60),
      _random.nextInt(60),
    );
  }

  BristolType _pickType(Map<BristolType, double> weights) {
    final List<BristolType> types = weights.keys.toList();
    return types[_pickIndex(
      types.map((BristolType t) => weights[t]!).toList(),
    )];
  }

  int _pickIndex(List<double> weights) {
    final double total = weights.fold(0, (double sum, double w) => sum + w);
    double roll = _random.nextDouble() * total;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        return i;
      }
    }
    return weights.length - 1;
  }
}
