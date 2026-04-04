import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

final dispatchDateFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final dispatchListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final dateFilter = ref.watch(dispatchDateFilterProvider);
  final query = <String, dynamic>{};
  if (dateFilter != null) {
    query['date'] = dateFilter.toIso8601String().split('T').first;
  }
  final response = await api.get('/dispatch', queryParameters: query);
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final dispatchPrefillProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, locationId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/dispatch/prefill/$locationId');
  return response.data as Map<String, dynamic>;
});

final locationsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/locations');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

Future<void> createDispatch(ApiClient api, Map<String, dynamic> payload) async {
  await api.post('/dispatch', data: payload);
}
