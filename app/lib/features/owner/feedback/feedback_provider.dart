import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

// ─── Filter Model ───────────────────────────────────────

class DashboardFilter {
  final String? locationId;
  final String? startDate;
  final String? endDate;

  const DashboardFilter({this.locationId, this.startDate, this.endDate});

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (locationId != null && locationId!.isNotEmpty) {
      params['locationId'] = locationId;
    }
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardFilter &&
          locationId == other.locationId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(locationId, startDate, endDate);
}

// ─── Providers ──────────────────────────────────────────

/// Feedback summary: averageRating, totalCount, ratingDistribution, topTags
final dashboardSummaryProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, DashboardFilter>(
        (ref, filter) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/feedback/summary',
      queryParameters: filter.toQueryParams());
  return response.data as Map<String, dynamic>? ?? {};
});

/// NPS data: nps score, location-level NPS breakdown
final dashboardNpsProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, DashboardFilter>(
        (ref, filter) async {
  final api = ref.read(apiClientProvider);
  final response =
      await api.get('/feedback/nps', queryParameters: filter.toQueryParams());
  return response.data as Map<String, dynamic>? ?? {};
});

/// Paginated feedback list (last 20)
final dashboardFeedbackListProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, DashboardFilter>(
        (ref, filter) async {
  final api = ref.read(apiClientProvider);
  final params = filter.toQueryParams();
  params['limit'] = 20;
  params['page'] = 1;
  final response =
      await api.get('/feedback/list', queryParameters: params);
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['items'] is List) {
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }
  if (data is Map && data['feedbacks'] is List) {
    return (data['feedbacks'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

/// Realtime feedback polling (by location)
final dashboardRealtimeProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, locationId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/feedback/realtime/$locationId');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  return [];
});

/// Locations list for dropdown filter
final dashboardLocationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/locations');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['locations'] is List) {
    return (data['locations'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});
