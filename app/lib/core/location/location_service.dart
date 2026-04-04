import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/constants.dart';
import 'haversine.dart';

/// Wraps the [geolocator] package with permission handling, position retrieval,
/// and geofence-style range checking for GPS attendance.
class LocationService {
  LocationService._();

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Check whether location services are enabled and permission is granted.
  /// Returns `true` when the app can read the device location.
  static Future<bool> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Request location permission from the user. Returns `true` if granted.
  static Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      dev.log('LocationService: location services are disabled');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      dev.log('LocationService: permission permanently denied');
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ---------------------------------------------------------------------------
  // Position
  // ---------------------------------------------------------------------------

  /// Get the device's current position.
  ///
  /// [desiredAccuracy] defaults to [LocationAccuracy.high] which is suitable
  /// for attendance geofencing.
  static Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw LocationServiceException('Location permission not granted');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: desiredAccuracy),
    );
  }

  /// Get the last known position (faster, may be stale).
  static Future<Position?> getLastKnownPosition() async {
    return Geolocator.getLastKnownPosition();
  }

  // ---------------------------------------------------------------------------
  // Geofencing helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if the point ([lat], [lng]) is within [radiusMeters] of
  /// the target ([targetLat], [targetLng]).
  ///
  /// Uses the Haversine formula for accuracy.
  static bool isWithinRange({
    required double lat,
    required double lng,
    required double targetLat,
    required double targetLng,
    int radiusMeters = AppConstants.gpsMaxDistanceMeters,
  }) {
    final distance =
        Haversine.distanceInMeters(lat, lng, targetLat, targetLng);
    return distance <= radiusMeters;
  }

  /// Convenience: check whether the device's *current* position is within
  /// range of a target. Requests permission and reads GPS in one call.
  static Future<LocationCheckResult> checkCurrentLocationInRange({
    required double targetLat,
    required double targetLng,
    int radiusMeters = AppConstants.gpsMaxDistanceMeters,
  }) async {
    final position = await getCurrentPosition();
    final distance = Haversine.distanceInMeters(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );
    return LocationCheckResult(
      position: position,
      distanceMeters: distance,
      isInRange: distance <= radiusMeters,
    );
  }
}

/// Result of a geofence range check.
class LocationCheckResult {
  final Position position;
  final double distanceMeters;
  final bool isInRange;

  const LocationCheckResult({
    required this.position,
    required this.distanceMeters,
    required this.isInRange,
  });

  @override
  String toString() =>
      'LocationCheckResult(lat: ${position.latitude}, lng: ${position.longitude}, '
      'distance: ${distanceMeters.toStringAsFixed(1)} m, inRange: $isInRange)';
}

/// Thrown when a location operation cannot proceed.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}

// -----------------------------------------------------------------------------
// Riverpod provider
// -----------------------------------------------------------------------------

/// Provides the current device position as an async value.
/// Widgets can use `ref.watch(currentPositionProvider)` to display location or
/// trigger attendance checks.
final currentPositionProvider = FutureProvider<Position>((ref) async {
  return LocationService.getCurrentPosition();
});
