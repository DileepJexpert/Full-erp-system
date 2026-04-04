import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('fromJson parses all flags', () {
      final flags = FeatureFlags.fromJson({
        'dispatch': true,
        'reconciliation': true,
        'billing': true,
        'inventory': true,
        'salary': true,
        'attendance': true,
        'cash': true,
        'expenses': true,
        'suppliers': true,
        'locations': true,
        'staff': true,
        'alerts': true,
        'performance': true,
        'reports': true,
        'upi': false,
        'printing': false,
      });
      expect(flags.dispatch, true);
      expect(flags.upi, false);
      expect(flags.printing, false);
    });

    test('defaults to true for missing flags', () {
      final flags = FeatureFlags.fromJson({});
      expect(flags.dispatch, true);
      expect(flags.billing, true);
    });

    test('all() returns all-true flags', () {
      final flags = FeatureFlags.all();
      expect(flags.dispatch, true);
      expect(flags.upi, true);
      expect(flags.printing, true);
    });
  });
}
