import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

class DashboardData {
  final double todayRevenue;
  final int todayBillCount;
  final int activeLocations;
  final int pendingDispatches;
  final int unreconciledDispatches;
  final double todayExpenses;
  final int unreadAlerts;
  final double cashCollectedToday;
  final double cashShortageToday;
  final double totalLossThisMonth;

  DashboardData({
    this.todayRevenue = 0,
    this.todayBillCount = 0,
    this.activeLocations = 0,
    this.pendingDispatches = 0,
    this.unreconciledDispatches = 0,
    this.todayExpenses = 0,
    this.unreadAlerts = 0,
    this.cashCollectedToday = 0,
    this.cashShortageToday = 0,
    this.totalLossThisMonth = 0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      todayRevenue: (json['todayRevenue'] ?? 0).toDouble(),
      todayBillCount: json['todayBillCount'] ?? 0,
      activeLocations: json['activeLocations'] ?? 0,
      pendingDispatches: json['pendingDispatches'] ?? 0,
      unreconciledDispatches: json['unreconciledDispatches'] ?? 0,
      todayExpenses: (json['todayExpenses'] ?? 0).toDouble(),
      unreadAlerts: json['unreadAlerts'] ?? 0,
      cashCollectedToday: (json['cashCollectedToday'] ?? 0).toDouble(),
      cashShortageToday: (json['cashShortageToday'] ?? 0).toDouble(),
      totalLossThisMonth: (json['totalLossThisMonth'] ?? 0).toDouble(),
    );
  }
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/dashboard/overview');
  return DashboardData.fromJson(response.data as Map<String, dynamic>);
});

final locationStatsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/dashboard/locations');
  return (response.data as List).cast<Map<String, dynamic>>();
});
