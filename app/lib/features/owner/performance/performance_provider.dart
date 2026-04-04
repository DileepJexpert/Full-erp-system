import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

class PerformanceScore {
  final String staffName;
  final String locationName;
  final double wastageScore;
  final double revenueScore;
  final double attendanceScore;
  final double cashScore;
  final double timelinessScore;
  final double alertsScore;
  final double totalScore;

  const PerformanceScore({
    required this.staffName,
    required this.locationName,
    required this.wastageScore,
    required this.revenueScore,
    required this.attendanceScore,
    required this.cashScore,
    required this.timelinessScore,
    required this.alertsScore,
    required this.totalScore,
  });

  factory PerformanceScore.fromJson(Map<String, dynamic> json) {
    return PerformanceScore(
      staffName: json['staffName'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      wastageScore: (json['wastageScore'] ?? 0).toDouble(),
      revenueScore: (json['revenueScore'] ?? 0).toDouble(),
      attendanceScore: (json['attendanceScore'] ?? 0).toDouble(),
      cashScore: (json['cashScore'] ?? 0).toDouble(),
      timelinessScore: (json['timelinessScore'] ?? 0).toDouble(),
      alertsScore: (json['alertsScore'] ?? 0).toDouble(),
      totalScore: (json['totalScore'] ?? 0).toDouble(),
    );
  }

  Map<String, double> get breakdown => {
        'Revenue': revenueScore,
        'Wastage': wastageScore,
        'Attendance': attendanceScore,
        'Cash': cashScore,
        'Timeliness': timelinessScore,
        'Alerts': alertsScore,
      };
}

final performanceDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: now,
  );
});

final performanceScoresProvider = FutureProvider.autoDispose<List<PerformanceScore>>((ref) async {
  final api = ref.read(apiClientProvider);
  final dateRange = ref.watch(performanceDateRangeProvider);
  final response = await api.get('/performance/scores', queryParameters: {
    'startDate': formatDateApi(dateRange.start),
    'endDate': formatDateApi(dateRange.end),
  });
  final list = response.data as List;
  final scores = list
      .map((e) => PerformanceScore.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
  return scores;
});
