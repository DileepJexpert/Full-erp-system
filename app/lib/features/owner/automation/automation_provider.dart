import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

final automationRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/automation/rules');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

Future<void> createRule(WidgetRef ref, Map<String, dynamic> rule) async {
  final api = ref.read(apiClientProvider);
  await api.post('/automation/rules', data: rule);
  ref.invalidate(automationRulesProvider);
}

Future<void> updateRule(WidgetRef ref, String id, Map<String, dynamic> data) async {
  final api = ref.read(apiClientProvider);
  await api.put('/automation/rules/$id', data: data);
  ref.invalidate(automationRulesProvider);
}

Future<void> deleteRule(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  await api.delete('/automation/rules/$id');
  ref.invalidate(automationRulesProvider);
}

Future<void> toggleRule(WidgetRef ref, String id, bool active) async {
  final api = ref.read(apiClientProvider);
  await api.put('/automation/rules/$id', data: {'active': active});
  ref.invalidate(automationRulesProvider);
}
