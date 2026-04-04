import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

/// Selected month/year state
final salaryMonthProvider = StateProvider<int>((ref) => DateTime.now().month);
final salaryYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Monthly salary data provider
final monthlySalaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final month = ref.watch(salaryMonthProvider);
  final year = ref.watch(salaryYearProvider);

  final response = await api.get('/salary/monthly', queryParameters: {
    'month': month,
    'year': year,
  });

  final data = response.data as Map<String, dynamic>;
  return data['data'] ?? data;
});
