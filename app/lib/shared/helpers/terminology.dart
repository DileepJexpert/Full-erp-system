import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/business_provider.dart';

/// Provides business-type-aware terminology labels.
/// Usage: final t = ref.watch(terminologyProvider);
///        Text(t.locations)  // "Kiosks" for food kiosk, "Stores" for kirana
class Terminology {
  final String location;    // singular: "Store", "Kiosk", "Center"
  final String locations;   // plural
  final String staff;       // singular: "Staff", "Faculty", "Agent"
  final String staffPlural; // plural
  final String offering;    // singular: "Item", "Service", "Course"
  final String offerings;   // plural

  const Terminology({
    this.location = 'Store',
    this.locations = 'Stores',
    this.staff = 'Staff',
    this.staffPlural = 'Staff',
    this.offering = 'Item',
    this.offerings = 'Items',
  });

  factory Terminology.fromConfig(BusinessConfig? config) {
    final loc = config?.locationLabel ?? 'Store';
    final stf = config?.staffLabel ?? 'Staff';
    final off = config?.offeringLabel ?? 'Item';
    return Terminology(
      location: loc,
      locations: _pluralize(loc),
      staff: stf,
      staffPlural: _pluralize(stf),
      offering: off,
      offerings: _pluralize(off),
    );
  }

  static String _pluralize(String s) {
    if (s.endsWith('y') && !s.endsWith('ey')) {
      return '${s.substring(0, s.length - 1)}ies';
    }
    if (s.endsWith('s') || s.endsWith('x') || s.endsWith('ch') || s.endsWith('sh')) {
      return '${s}es';
    }
    return '${s}s';
  }
}

final terminologyProvider = Provider<Terminology>((ref) {
  final configAsync = ref.watch(businessConfigProvider);
  return configAsync.when(
    data: (config) => Terminology.fromConfig(config),
    loading: () => const Terminology(),
    error: (_, __) => const Terminology(),
  );
});
