import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final expensesProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, String>>((ref, params) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/expenses', queryParameters: params);
  final data = res.data['data'] ?? res.data;
  return List<Map<String, dynamic>>.from(data is List ? data : []);
});
