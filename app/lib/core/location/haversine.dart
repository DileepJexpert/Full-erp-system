import 'dart:math';

/// Pure-Dart implementation of the Haversine formula.
///
/// No external dependencies -- uses only `dart:math`.
class Haversine {
  Haversine._();

  /// Mean radius of the Earth in metres (WGS-84).
  static const double _earthRadiusMeters = 6371008.8;

  /// Returns the great-circle distance in **metres** between two points
  /// specified in decimal degrees.
  static double distanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  /// Convenience: returns distance in **kilometres**.
  static double distanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return distanceInMeters(lat1, lon1, lat2, lon2) / 1000.0;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
