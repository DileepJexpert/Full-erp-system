import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

enum AlertType {
  HIGH_WASTAGE,
  CASH_MISMATCH,
  LATE_OPENING,
  LOW_STOCK,
  EXPENSE_LIMIT,
  ATTENDANCE_ISSUE,
  DISPATCH_DELAY,
  UNKNOWN;

  static AlertType fromString(String value) {
    return AlertType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AlertType.UNKNOWN,
    );
  }
}

enum AlertSeverity {
  critical,
  warning,
  info;

  static AlertSeverity fromString(String value) {
    return AlertSeverity.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AlertSeverity.info,
    );
  }
}

class Alert {
  final String id;
  final AlertType type;
  final String message;
  final AlertSeverity severity;
  final String locationName;
  final DateTime createdAt;
  final bool isRead;

  const Alert({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.locationName,
    required this.createdAt,
    required this.isRead,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      type: AlertType.fromString(json['type'] as String? ?? ''),
      message: json['message'] as String? ?? '',
      severity: AlertSeverity.fromString(json['severity'] as String? ?? 'info'),
      locationName: json['locationName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      type: type,
      message: message,
      severity: severity,
      locationName: locationName,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

final alertsProvider = FutureProvider.autoDispose<List<Alert>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/alerts');
  final list = response.data as List;
  return list
      .map((e) => Alert.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final alertFilterProvider = StateProvider<AlertSeverity?>((ref) => null);

final filteredAlertsProvider = Provider.autoDispose<AsyncValue<List<Alert>>>((ref) {
  final alertsAsync = ref.watch(alertsProvider);
  final filter = ref.watch(alertFilterProvider);
  return alertsAsync.whenData((alerts) {
    if (filter == null) return alerts;
    return alerts.where((a) => a.severity == filter).toList();
  });
});

final unreadCountProvider = Provider.autoDispose<int>((ref) {
  final alertsAsync = ref.watch(alertsProvider);
  return alertsAsync.whenOrNull(data: (alerts) => alerts.where((a) => !a.isRead).length) ?? 0;
});

Future<void> markAlertAsRead(WidgetRef ref, String alertId) async {
  final api = ref.read(apiClientProvider);
  await api.patch('/alerts/$alertId', data: {'isRead': true});
  ref.invalidate(alertsProvider);
}
