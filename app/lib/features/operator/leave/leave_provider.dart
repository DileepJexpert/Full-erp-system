import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

final operatorLeaveRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/leave/my-requests');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

Future<void> submitLeaveRequest(
  WidgetRef ref, {
  required String startDate,
  required String endDate,
  required String leaveType,
  required String reason,
}) async {
  final api = ref.read(apiClientProvider);
  await api.post('/leave/request', data: {
    'startDate': startDate,
    'endDate': endDate,
    'leaveType': leaveType,
    'reason': reason,
  });
  ref.invalidate(operatorLeaveRequestsProvider);
}
