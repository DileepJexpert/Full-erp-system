import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';

// --- Kiosk Configuration Model ---

class KioskConfig {
  final String locationId;
  final String locationName;
  final String businessName;
  final KioskDisplayMode displayMode;
  final int autoResetSec;
  final bool showBilingual;
  final List<String> negativeTags;
  final List<String> positiveTags;
  final String kioskToken;
  final String deviceId;
  final String pin;

  const KioskConfig({
    this.locationId = '',
    this.locationName = '',
    this.businessName = '',
    this.displayMode = KioskDisplayMode.simple,
    this.autoResetSec = 8,
    this.showBilingual = true,
    this.negativeTags = const [
      'slow_service',
      'bad_quality',
      'rude_staff',
      'wrong_order',
      'not_clean',
      'overpriced',
    ],
    this.positiveTags = const [
      'tasty_food',
      'fast_service',
      'friendly_staff',
      'clean_place',
      'good_value',
      'will_recommend',
    ],
    this.kioskToken = '',
    this.deviceId = '',
    this.pin = '',
  });

  KioskConfig copyWith({
    String? locationId,
    String? locationName,
    String? businessName,
    KioskDisplayMode? displayMode,
    int? autoResetSec,
    bool? showBilingual,
    List<String>? negativeTags,
    List<String>? positiveTags,
    String? kioskToken,
    String? deviceId,
    String? pin,
  }) {
    return KioskConfig(
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      businessName: businessName ?? this.businessName,
      displayMode: displayMode ?? this.displayMode,
      autoResetSec: autoResetSec ?? this.autoResetSec,
      showBilingual: showBilingual ?? this.showBilingual,
      negativeTags: negativeTags ?? this.negativeTags,
      positiveTags: positiveTags ?? this.positiveTags,
      kioskToken: kioskToken ?? this.kioskToken,
      deviceId: deviceId ?? this.deviceId,
      pin: pin ?? this.pin,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'locationName': locationName,
        'businessName': businessName,
        'displayMode': displayMode.name,
        'autoResetSec': autoResetSec,
        'showBilingual': showBilingual,
        'negativeTags': negativeTags,
        'positiveTags': positiveTags,
        'kioskToken': kioskToken,
        'deviceId': deviceId,
        'pin': pin,
      };

  factory KioskConfig.fromJson(Map<String, dynamic> json) {
    return KioskConfig(
      locationId: json['locationId'] ?? '',
      locationName: json['locationName'] ?? '',
      businessName: json['businessName'] ?? '',
      displayMode: KioskDisplayMode.values.firstWhere(
        (m) => m.name == json['displayMode'],
        orElse: () => KioskDisplayMode.simple,
      ),
      autoResetSec: json['autoResetSec'] ?? 8,
      showBilingual: json['showBilingual'] ?? true,
      negativeTags: (json['negativeTags'] as List?)?.cast<String>() ??
          const [
            'slow_service',
            'bad_quality',
            'rude_staff',
            'wrong_order',
            'not_clean',
            'overpriced',
          ],
      positiveTags: (json['positiveTags'] as List?)?.cast<String>() ??
          const [
            'tasty_food',
            'fast_service',
            'friendly_staff',
            'clean_place',
            'good_value',
            'will_recommend',
          ],
      kioskToken: json['kioskToken'] ?? '',
      deviceId: json['deviceId'] ?? '',
      pin: json['pin'] ?? '',
    );
  }
}

enum KioskDisplayMode { simple, withComment, withTags }

// --- Kiosk Config StateNotifier ---

class KioskConfigNotifier extends StateNotifier<KioskConfig> {
  final FlutterSecureStorage _storage;

  KioskConfigNotifier(this._storage) : super(const KioskConfig()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final raw = await _storage.read(key: 'kiosk_config');
      if (raw != null) {
        state = KioskConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // ignore corrupt data
    }
  }

  Future<void> _saveToStorage() async {
    await _storage.write(
      key: 'kiosk_config',
      value: jsonEncode(state.toJson()),
    );
  }

  void update(KioskConfig Function(KioskConfig) updater) {
    state = updater(state);
  }

  Future<void> saveAndPersist(KioskConfig config) async {
    state = config;
    await _saveToStorage();
  }

  Future<void> clear() async {
    state = const KioskConfig();
    await _storage.delete(key: 'kiosk_config');
  }
}

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final kioskConfigProvider =
    StateNotifierProvider<KioskConfigNotifier, KioskConfig>((ref) {
  return KioskConfigNotifier(ref.read(_secureStorageProvider));
});

// --- Kiosk Auth ---

final kioskAuthProvider = Provider<Future<bool> Function({
  required String locationId,
  required String deviceId,
})>((ref) {
  return ({required locationId, required deviceId}) async {
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.post('/feedback/kiosk-auth', data: {
        'locationId': locationId,
        'deviceId': deviceId,
      });
      final data = response.data as Map<String, dynamic>? ?? {};
      final token = data['kioskToken'] as String? ?? '';
      if (token.isNotEmpty) {
        final notifier = ref.read(kioskConfigProvider.notifier);
        notifier.update((c) => c.copyWith(kioskToken: token, deviceId: deviceId));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  };
});

// --- Submit Feedback ---

final submitFeedbackProvider = Provider<Future<bool> Function({
  required int rating,
  String? comment,
  List<String>? tags,
})>((ref) {
  return ({required rating, comment, tags}) async {
    final api = ref.read(apiClientProvider);
    final config = ref.read(kioskConfigProvider);
    try {
      await api.post('/feedback/submit', data: {
        'locationId': config.locationId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        'kioskToken': config.kioskToken,
        'deviceId': config.deviceId,
      });
      return true;
    } catch (_) {
      // Silently fail - kiosk should not block on API errors
      return false;
    }
  };
});

// --- Feedback Summary (for dashboard) ---

class FeedbackFilter {
  final String? locationId;
  final String? startDate;
  final String? endDate;

  const FeedbackFilter({this.locationId, this.startDate, this.endDate});

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (locationId != null && locationId!.isNotEmpty) {
      params['locationId'] = locationId;
    }
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackFilter &&
          locationId == other.locationId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(locationId, startDate, endDate);
}

final feedbackSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, FeedbackFilter>(
        (ref, filter) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/feedback/summary',
      queryParameters: filter.toQueryParams());
  return response.data as Map<String, dynamic>? ?? {};
});

final feedbackNpsProvider =
    FutureProvider.family<Map<String, dynamic>, FeedbackFilter>(
        (ref, filter) async {
  final api = ref.read(apiClientProvider);
  final response =
      await api.get('/feedback/nps', queryParameters: filter.toQueryParams());
  return response.data as Map<String, dynamic>? ?? {};
});

final realtimeFeedbackProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, locationId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/feedback/realtime/$locationId');
  return (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
});

final locationsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/locations');
  final data = response.data;
  if (data is List) {
    return data.cast<Map<String, dynamic>>();
  }
  if (data is Map && data['locations'] is List) {
    return (data['locations'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});
