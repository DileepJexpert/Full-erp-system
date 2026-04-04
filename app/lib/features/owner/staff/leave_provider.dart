import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

final leaveRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/leave/requests');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

Future<void> approveLeave(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  await api.put('/leave/requests/$id/approve');
  ref.invalidate(leaveRequestsProvider);
}

Future<void> rejectLeave(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  await api.put('/leave/requests/$id/reject');
  ref.invalidate(leaveRequestsProvider);
}
