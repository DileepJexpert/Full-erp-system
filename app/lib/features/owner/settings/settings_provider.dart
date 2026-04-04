import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

class BusinessSettings {
  final String businessName;
  final String gstNumber;
  final String? logoUrl;
  final Map<String, bool> featureFlags;
  final String upiId;
  final String upiPayeeName;
  final NotificationPreferences notificationPreferences;

  const BusinessSettings({
    this.businessName = '',
    this.gstNumber = '',
    this.logoUrl,
    this.featureFlags = const {},
    this.upiId = '',
    this.upiPayeeName = '',
    this.notificationPreferences = const NotificationPreferences(),
  });

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      businessName: json['businessName'] as String? ?? '',
      gstNumber: json['gstNumber'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      featureFlags: (json['featureFlags'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {},
      upiId: json['upiId'] as String? ?? '',
      upiPayeeName: json['upiPayeeName'] as String? ?? '',
      notificationPreferences: NotificationPreferences.fromJson(
        json['notificationPreferences'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'gstNumber': gstNumber,
        'logoUrl': logoUrl,
        'featureFlags': featureFlags,
        'upiId': upiId,
        'upiPayeeName': upiPayeeName,
        'notificationPreferences': notificationPreferences.toJson(),
      };

  BusinessSettings copyWith({
    String? businessName,
    String? gstNumber,
    String? logoUrl,
    Map<String, bool>? featureFlags,
    String? upiId,
    String? upiPayeeName,
    NotificationPreferences? notificationPreferences,
  }) {
    return BusinessSettings(
      businessName: businessName ?? this.businessName,
      gstNumber: gstNumber ?? this.gstNumber,
      logoUrl: logoUrl ?? this.logoUrl,
      featureFlags: featureFlags ?? this.featureFlags,
      upiId: upiId ?? this.upiId,
      upiPayeeName: upiPayeeName ?? this.upiPayeeName,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }
}

class NotificationPreferences {
  final bool alertsEnabled;
  final bool dailySummary;
  final bool cashAlerts;
  final bool wastageAlerts;
  final bool attendanceAlerts;

  const NotificationPreferences({
    this.alertsEnabled = true,
    this.dailySummary = true,
    this.cashAlerts = true,
    this.wastageAlerts = true,
    this.attendanceAlerts = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      dailySummary: json['dailySummary'] as bool? ?? true,
      cashAlerts: json['cashAlerts'] as bool? ?? true,
      wastageAlerts: json['wastageAlerts'] as bool? ?? true,
      attendanceAlerts: json['attendanceAlerts'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'alertsEnabled': alertsEnabled,
        'dailySummary': dailySummary,
        'cashAlerts': cashAlerts,
        'wastageAlerts': wastageAlerts,
        'attendanceAlerts': attendanceAlerts,
      };

  NotificationPreferences copyWith({
    bool? alertsEnabled,
    bool? dailySummary,
    bool? cashAlerts,
    bool? wastageAlerts,
    bool? attendanceAlerts,
  }) {
    return NotificationPreferences(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      dailySummary: dailySummary ?? this.dailySummary,
      cashAlerts: cashAlerts ?? this.cashAlerts,
      wastageAlerts: wastageAlerts ?? this.wastageAlerts,
      attendanceAlerts: attendanceAlerts ?? this.attendanceAlerts,
    );
  }
}

class SettingsNotifier extends StateNotifier<AsyncValue<BusinessSettings>> {
  final ApiClient _api;

  SettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get('/business/settings');
      state = AsyncValue.data(
        BusinessSettings.fromJson(response.data as Map<String, dynamic>),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() => _load();

  void updateLocal(BusinessSettings settings) {
    state = AsyncValue.data(settings);
  }

  Future<bool> save() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    try {
      await _api.put('/business/settings', data: current.toJson());
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<BusinessSettings>>((ref) {
  final api = ref.read(apiClientProvider);
  return SettingsNotifier(api);
});
