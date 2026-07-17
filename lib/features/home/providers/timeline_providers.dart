import 'dart:collection';

import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timeline_providers.g.dart';

/// Summary of today's bowel movements.
class TodaySummary {
  const TodaySummary({
    required this.count,
    required this.byType,
  });

  /// Total number of movements recorded today.
  final int count;

  /// Breakdown of today's movements by Bristol type.
  /// Types with zero entries are absent from the map.
  final Map<BristolType, int> byType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TodaySummary) return false;
    if (other.count != count) return false;
    if (other.byType.length != byType.length) return false;
    for (final MapEntry<BristolType, int> entry in byType.entries) {
      if (other.byType[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(count, Object.hashAll(byType.entries));

  @override
  String toString() => 'TodaySummary(count: $count, byType: $byType)';
}

/// Watches the last 30 days of bowel movements, sorted newest-first.
///
/// The range is `[30 days ago midnight, start of tomorrow)`.
@riverpod
Stream<List<BowelMovement>> timeline(Ref ref) {
  final BowelMovementRepository repo =
      ref.watch(bowelMovementRepositoryProvider);
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime from = today.subtract(const Duration(days: 30));
  final DateTime to = today.add(const Duration(days: 1));
  return repo.watchRange(from, to);
}

/// Today's movement count and Bristol-type breakdown, derived from
/// [timelineProvider].
///
/// Returns an empty summary while the timeline stream is still loading.
@riverpod
TodaySummary todaySummary(Ref ref) {
  final List<BowelMovement> entries =
      ref.watch(timelineProvider).value ?? <BowelMovement>[];
  final DateTime now = DateTime.now();
  final DateTime todayStart = DateTime(now.year, now.month, now.day);
  final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));

  final List<BowelMovement> todayEntries = entries
      .where(
        (BowelMovement e) =>
            !e.occurredAt.isBefore(todayStart) &&
            e.occurredAt.isBefore(tomorrowStart),
      )
      .toList();

  final Map<BristolType, int> byType = <BristolType, int>{};
  for (final BowelMovement entry in todayEntries) {
    byType[entry.bristolType] = (byType[entry.bristolType] ?? 0) + 1;
  }

  return TodaySummary(count: todayEntries.length, byType: byType);
}

/// Groups [entries] by local calendar day, sorted newest-first.
///
/// Returns a [LinkedHashMap] whose keys are midnight [DateTime]s (local)
/// and whose values are the entries for that day, preserving the input order
/// within each group (newest-first when the input is newest-first).
LinkedHashMap<DateTime, List<BowelMovement>> groupEntriesByDay(
  List<BowelMovement> entries,
) {
  final Map<DateTime, List<BowelMovement>> map =
      <DateTime, List<BowelMovement>>{};
  for (final BowelMovement entry in entries) {
    final DateTime day = DateTime(
      entry.occurredAt.year,
      entry.occurredAt.month,
      entry.occurredAt.day,
    );
    (map[day] ??= <BowelMovement>[]).add(entry);
  }

  final List<DateTime> sortedKeys = map.keys.toList()
    ..sort((DateTime a, DateTime b) => b.compareTo(a));

  final LinkedHashMap<DateTime, List<BowelMovement>> result =
      LinkedHashMap<DateTime, List<BowelMovement>>();
  for (final DateTime key in sortedKeys) {
    result[key] = map[key]!;
  }
  return result;
}
