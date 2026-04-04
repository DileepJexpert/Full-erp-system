import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

final budgetsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/budgets');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final budgetVarianceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, month) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/budgets/$month/variance');
  return response.data as Map<String, dynamic>;
});

final selectedBudgetMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});
