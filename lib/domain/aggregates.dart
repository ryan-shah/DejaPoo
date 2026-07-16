import 'package:dejapoo/domain/bristol_type.dart';

/// Count of events of one [BristolType] on one calendar [day]
/// (local, date-only — the time components are always zero).
class DailyTypeCount {
  const DailyTypeCount({
    required this.day,
    required this.type,
    required this.count,
  });

  final DateTime day;
  final BristolType type;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DailyTypeCount &&
      other.day == day &&
      other.type == type &&
      other.count == count;

  @override
  int get hashCode => Object.hash(day, type, count);

  @override
  String toString() => 'DailyTypeCount($day, ${type.name}, $count)';
}

/// Count of events of one [BristolType] within one period (a week or a
/// month), identified by the period's first day.
class PeriodTypeCount {
  const PeriodTypeCount({
    required this.periodStart,
    required this.type,
    required this.count,
  });

  final DateTime periodStart;
  final BristolType type;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is PeriodTypeCount &&
      other.periodStart == periodStart &&
      other.type == type &&
      other.count == count;

  @override
  int get hashCode => Object.hash(periodStart, type, count);

  @override
  String toString() => 'PeriodTypeCount($periodStart, ${type.name}, $count)';
}

/// The Monday starting the ISO week containing [day].
DateTime weekStart(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

/// Rolls daily counts up into ISO weeks (Monday start).
List<PeriodTypeCount> rollUpByWeek(List<DailyTypeCount> daily) =>
    _rollUp(daily, weekStart);

/// Rolls daily counts up into calendar months.
List<PeriodTypeCount> rollUpByMonth(List<DailyTypeCount> daily) =>
    _rollUp(daily, (DateTime day) => DateTime(day.year, day.month));

List<PeriodTypeCount> _rollUp(
  List<DailyTypeCount> daily,
  DateTime Function(DateTime day) periodOf,
) {
  final Map<(DateTime, BristolType), int> totals =
      <(DateTime, BristolType), int>{};
  for (final DailyTypeCount d in daily) {
    final (DateTime, BristolType) key = (periodOf(d.day), d.type);
    totals[key] = (totals[key] ?? 0) + d.count;
  }
  final List<PeriodTypeCount> result = <PeriodTypeCount>[
    for (final MapEntry<(DateTime, BristolType), int> e in totals.entries)
      PeriodTypeCount(periodStart: e.key.$1, type: e.key.$2, count: e.value),
  ]..sort((PeriodTypeCount a, PeriodTypeCount b) {
      final int byPeriod = a.periodStart.compareTo(b.periodStart);
      return byPeriod != 0 ? byPeriod : a.type.number - b.type.number;
    });
  return result;
}

/// The longest run of consecutive days that each have at least one event.
/// Returns 0 for no events.
int longestStreak(Iterable<DateTime> eventDays) {
  final List<DateTime> days = _sortedUniqueDays(eventDays);
  int longest = days.isEmpty ? 0 : 1;
  int current = longest;
  for (int i = 1; i < days.length; i++) {
    current = _daysBetween(days[i - 1], days[i]) == 1 ? current + 1 : 1;
    if (current > longest) {
      longest = current;
    }
  }
  return longest;
}

/// The longest run of consecutive zero-event days strictly between two event
/// days. Returns 0 with fewer than two distinct event days.
int longestGap(Iterable<DateTime> eventDays) {
  final List<DateTime> days = _sortedUniqueDays(eventDays);
  int longest = 0;
  for (int i = 1; i < days.length; i++) {
    final int gap = _daysBetween(days[i - 1], days[i]) - 1;
    if (gap > longest) {
      longest = gap;
    }
  }
  return longest;
}

/// The number of consecutive event days ending at [today] — or, when [today]
/// has no events yet, ending at yesterday. Returns 0 if neither has events.
int currentStreak(Iterable<DateTime> eventDays, DateTime today) {
  final Set<DateTime> days = _sortedUniqueDays(eventDays).toSet();
  DateTime cursor = DateTime(today.year, today.month, today.day);
  if (!days.contains(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  int streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

List<DateTime> _sortedUniqueDays(Iterable<DateTime> days) {
  final Set<DateTime> unique = <DateTime>{
    for (final DateTime d in days) DateTime(d.year, d.month, d.day),
  };
  return unique.toList()..sort();
}

/// Whole calendar days from [a] to [b] (date components only, DST-safe).
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
