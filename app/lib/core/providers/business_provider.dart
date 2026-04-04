import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../auth/auth_provider.dart';
import '../../config/feature_flags.dart';

class BusinessConfig {
  final String id;
  final String name;
  final String type;
  final String locationLabel;
  final String staffLabel;
  final String offeringLabel;
  final FeatureFlags features;

  const BusinessConfig({
    required this.id,
    required this.name,
    required this.type,
    this.locationLabel = 'Store',
    this.staffLabel = 'Staff',
    this.offeringLabel = 'Item',
    this.features = const FeatureFlags(),
  });

  factory BusinessConfig.fromJson(Map<String, dynamic> json) {
    return BusinessConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      locationLabel: json['locationLabel'] ?? 'Store',
      staffLabel: json['staffLabel'] ?? 'Staff',
      offeringLabel: json['offeringLabel'] ?? 'Item',
      features: FeatureFlags.fromJson(json),
    );
  }
}

final businessConfigProvider = FutureProvider<BusinessConfig>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/config');
  return BusinessConfig.fromJson(response.data as Map<String, dynamic>);
});
