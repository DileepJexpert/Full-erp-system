import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

/// Date range state for cash collection filter
final cashStartDateProvider = StateProvider<DateTime?>((ref) => null);
final cashEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// Cash collections list provider with date range filtering
final cashCollectionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final startDate = ref.watch(cashStartDateProvider);
  final endDate = ref.watch(cashEndDateProvider);

  final queryParams = <String, dynamic>{};
  if (startDate != null) {
    queryParams['startDate'] = formatDateApi(startDate);
  }
  if (endDate != null) {
    queryParams['endDate'] = formatDateApi(endDate);
  }

  final response =
      await api.get('/cash-collections', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});
