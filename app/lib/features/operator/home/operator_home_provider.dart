import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

class TodaySummary {
  final double todayRevenue;
  final int billCount;
  final int pendingRecon;
  final String attendanceStatus; // 'CHECKED_IN', 'CHECKED_OUT', 'ABSENT'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  TodaySummary({
    this.todayRevenue = 0,
    this.billCount = 0,
    this.pendingRecon = 0,
    this.attendanceStatus = 'ABSENT',
    this.checkInTime,
    this.checkOutTime,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      todayRevenue: (json['todayRevenue'] ?? 0).toDouble(),
      billCount: json['billCount'] ?? 0,
      pendingRecon: json['pendingRecon'] ?? 0,
      attendanceStatus: json['attendanceStatus'] ?? 'ABSENT',
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'])
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'])
          : null,
    );
  }

  bool get isCheckedIn => attendanceStatus == 'CHECKED_IN';
  bool get isCheckedOut => attendanceStatus == 'CHECKED_OUT';
  bool get isAbsent => attendanceStatus == 'ABSENT';
}

final operatorSummaryProvider =
    FutureProvider.autoDispose<TodaySummary>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/operator/today-summary');
  return TodaySummary.fromJson(response.data as Map<String, dynamic>);
});

final attendanceActionProvider =
    StateNotifierProvider<AttendanceActionNotifier, AsyncValue<void>>((ref) {
  final api = ref.read(apiClientProvider);
  return AttendanceActionNotifier(api);
});

class AttendanceActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;

  AttendanceActionNotifier(this._api) : super(const AsyncData(null));

  Future<bool> checkIn() async {
    state = const AsyncLoading();
    try {
      await _api.post('/operator/check-in');
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> checkOut() async {
    state = const AsyncLoading();
    try {
      await _api.post('/operator/check-out');
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
