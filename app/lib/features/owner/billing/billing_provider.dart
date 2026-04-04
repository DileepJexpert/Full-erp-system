import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

/// Date range state for bills filter
final billsStartDateProvider = StateProvider<DateTime?>((ref) => null);
final billsEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// Bills list provider with date range filtering
final billsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final startDate = ref.watch(billsStartDateProvider);
  final endDate = ref.watch(billsEndDateProvider);

  final queryParams = <String, dynamic>{};
  if (startDate != null) {
    queryParams['startDate'] = formatDateApi(startDate);
  }
  if (endDate != null) {
    queryParams['endDate'] = formatDateApi(endDate);
  }

  final response =
      await api.get('/billing/bills', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});
