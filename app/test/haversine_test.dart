import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/core/location/haversine.dart';

void main() {
  group('Haversine distance', () {
    test('same point returns 0', () {
      expect(distanceInMeters(28.6139, 77.2090, 28.6139, 77.2090), closeTo(0, 0.1));
    });

    test('known distance Delhi to Mumbai ~1400km', () {
      final d = distanceInMeters(28.6139, 77.2090, 19.0760, 72.8777);
      expect(d, closeTo(1153000, 50000)); // ~1153 km
    });

    test('short distance within GPS attendance range', () {
      // ~100 meters apart
      final d = distanceInMeters(28.6139, 77.2090, 28.6148, 77.2090);
      expect(d, closeTo(100, 20));
    });

    test('antipodal points ~20000km', () {
      final d = distanceInMeters(0, 0, 0, 180);
      expect(d, closeTo(20015000, 100000));
    });

    test('negative coordinates work', () {
      final d = distanceInMeters(-33.8688, 151.2093, -37.8136, 144.9631);
      expect(d, greaterThan(700000)); // Sydney to Melbourne ~714km
      expect(d, lessThan(800000));
    });
  });
}
