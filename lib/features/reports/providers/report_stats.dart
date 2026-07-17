import 'package:dejapoo/domain/domain.dart';

/// Summary statistics for the currently selected [ReportRange].
class ReportStats {
  const ReportStats({
    required this.total,
    required this.averagePerDay,
    required this.mostCommonType,
    required this.healthyPercentage,
    required this.longestGapDays,
  });

  /// Total number of movements in the range.
  final int total;

  /// [total] divided by the number of days in the range.
  final double averagePerDay;

  /// The Bristol type with the most movements in the range, or null when
  /// [total] is 0.
  final BristolType? mostCommonType;

  /// Percentage (0-100) of movements whose Bristol type is 3, 4, or 5.
  final double healthyPercentage;

  /// Longest run of consecutive zero-event days strictly between two event
  /// days within the range.
  final int longestGapDays;

  @override
  bool operator ==(Object other) =>
      other is ReportStats &&
      other.total == total &&
      other.averagePerDay == averagePerDay &&
      other.mostCommonType == mostCommonType &&
      other.healthyPercentage == healthyPercentage &&
      other.longestGapDays == longestGapDays;

  @override
  int get hashCode => Object.hash(
        total,
        averagePerDay,
        mostCommonType,
        healthyPercentage,
        longestGapDays,
      );

  @override
  String toString() => 'ReportStats(total: $total, '
      'averagePerDay: $averagePerDay, '
      'mostCommonType: $mostCommonType, '
      'healthyPercentage: $healthyPercentage, '
      'longestGapDays: $longestGapDays)';
}
