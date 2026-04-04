import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';

final currentWeekStartProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1)); // Monday
});

final shiftScheduleProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final weekStart = ref.watch(currentWeekStartProvider);
  final response = await api.get(
    '/shifts/schedule',
    queryParameters: {'weekStart': formatDateApi(weekStart)},
  );
  return response.data as Map<String, dynamic>;
});

Future<void> assignShift(WidgetRef ref, Map<String, dynamic> data) async {
  final api = ref.read(apiClientProvider);
  await api.post('/shifts/assign', data: data);
  ref.invalidate(shiftScheduleProvider);
}
