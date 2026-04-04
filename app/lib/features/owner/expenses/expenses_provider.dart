import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

/// Date range state for expenses filter
final expensesStartDateProvider = StateProvider<DateTime?>((ref) => null);
final expensesEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// Expenses list provider with date range filtering
final expensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final startDate = ref.watch(expensesStartDateProvider);
  final endDate = ref.watch(expensesEndDateProvider);

  final queryParams = <String, dynamic>{};
  if (startDate != null) {
    queryParams['startDate'] = formatDateApi(startDate);
  }
  if (endDate != null) {
    queryParams['endDate'] = formatDateApi(endDate);
  }

  final response = await api.get('/expenses', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});
