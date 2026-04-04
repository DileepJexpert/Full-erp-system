import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

class ReportRequest {
  final String type;
  final DateTimeRange dateRange;

  const ReportRequest({required this.type, required this.dateRange});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportRequest &&
          other.type == type &&
          other.dateRange.start == dateRange.start &&
          other.dateRange.end == dateRange.end;

  @override
  int get hashCode => Object.hash(type, dateRange.start, dateRange.end);
}

class ReportData {
  final String title;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? summary;

  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
    this.summary,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      title: json['title'] as String? ?? '',
      columns: (json['columns'] as List?)?.cast<String>() ?? [],
      rows: (json['rows'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      summary: json['summary'] as Map<String, dynamic>?,
    );
  }
}

final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: now,
  );
});

final reportProvider = FutureProvider.autoDispose.family<ReportData, ReportRequest>((ref, request) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reports/${request.type}', queryParameters: {
    'startDate': formatDateApi(request.dateRange.start),
    'endDate': formatDateApi(request.dateRange.end),
  });
  return ReportData.fromJson(response.data as Map<String, dynamic>);
});
