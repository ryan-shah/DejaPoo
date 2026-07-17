import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/domain/report_range.dart';
import 'package:dejapoo/features/reports/providers/report_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_providers.g.dart';

/// Set of Bristol types considered "healthy" (normal stool).
const Set<BristolType> _healthyTypes = <BristolType>{
  BristolType.type3,
  BristolType.type4,
  BristolType.type5,
};

/// The currently selected time range for the reports screen.
///
/// Defaults to the calendar month containing "now" at construction time.
@riverpod
class SelectedReportRange extends _$SelectedReportRange {
  @override
  ReportRange build() => ReportRange.month(anchor: DateTime.now());

  /// Replaces the selected range outright (e.g. from a period-kind switch or
  /// a custom date-range picker).
  void setRange(ReportRange range) {
    state = range;
  }

  /// Steps the selected range forward by one period.
  void next() {
    state = state.next();
  }

  /// Steps the selected range backward by one period.
  void previous() {
    state = state.previous();
  }
}

/// Watches movements within the currently selected [ReportRange].
///
/// Converts the range's inclusive [ReportRange.lastDay] into the half-open
/// `to` instant expected by [BowelMovementRepository.watchRange].
@riverpod
Stream<List<BowelMovement>> reportEntries(Ref ref) {
  final BowelMovementRepository repo =
      ref.watch(bowelMovementRepositoryProvider);
  final ReportRange range = ref.watch(selectedReportRangeProvider);
  final DateTime from = range.firstDay;
  final DateTime to = DateTime(
    range.lastDay.year,
    range.lastDay.month,
    range.lastDay.day + 1,
  );
  return repo.watchRange(from, to);
}

/// Per-day, per-type counts for the currently selected [ReportRange].
@riverpod
Future<List<DailyTypeCount>> reportDailyTypeCounts(Ref ref) {
  final BowelMovementRepository repo =
      ref.watch(bowelMovementRepositoryProvider);
  final ReportRange range = ref.watch(selectedReportRangeProvider);
  return repo.dailyTypeCounts(range.firstDay, range.lastDay);
}

/// Total events per Bristol type for the currently selected [ReportRange].
@riverpod
Future<Map<BristolType, int>> reportTypeDistribution(Ref ref) {
  final BowelMovementRepository repo =
      ref.watch(bowelMovementRepositoryProvider);
  final ReportRange range = ref.watch(selectedReportRangeProvider);
  return repo.typeDistribution(range.firstDay, range.lastDay);
}

/// Summary statistics for the currently selected [ReportRange].
@riverpod
Future<ReportStats> reportStats(Ref ref) async {
  final BowelMovementRepository repo =
      ref.watch(bowelMovementRepositoryProvider);
  final ReportRange range = ref.watch(selectedReportRangeProvider);
  // Watch entries so this provider invalidates on any live change.
  ref.watch(reportEntriesProvider);

  final int total = await repo.totalCount(range.firstDay, range.lastDay);
  final double averagePerDay =
      await repo.averagePerDay(range.firstDay, range.lastDay);
  final int longestGapDays =
      await repo.longestGapDays(range.firstDay, range.lastDay);
  final Map<BristolType, int> distribution =
      await repo.typeDistribution(range.firstDay, range.lastDay);

  BristolType? mostCommonType;
  int mostCommonCount = 0;
  for (final MapEntry<BristolType, int> entry in distribution.entries) {
    if (entry.value > mostCommonCount) {
      mostCommonCount = entry.value;
      mostCommonType = entry.key;
    }
  }

  int healthyCount = 0;
  for (final MapEntry<BristolType, int> entry in distribution.entries) {
    if (_healthyTypes.contains(entry.key)) {
      healthyCount += entry.value;
    }
  }
  final double healthyPercentage =
      total == 0 ? 0.0 : (healthyCount / total) * 100;

  return ReportStats(
    total: total,
    averagePerDay: averagePerDay,
    mostCommonType: mostCommonType,
    healthyPercentage: healthyPercentage,
    longestGapDays: longestGapDays,
  );
}
