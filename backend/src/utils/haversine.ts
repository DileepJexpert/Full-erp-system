const EARTH_RADIUS_METERS = 6_371_000;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

export function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_METERS * c;
}

export interface ProximityResult {
  distance: number;
  withinRange: boolean;
  isRemote: boolean;
}

export function checkProximity(
  checkInLat: number,
  checkInLng: number,
  locationLat: number,
  locationLng: number,
  maxDistance = 200,
  remoteThreshold = 100,
): ProximityResult {
  const distance = haversineDistance(checkInLat, checkInLng, locationLat, locationLng);
  return {
    distance: Math.round(distance),
    withinRange: distance <= maxDistance,
    isRemote: distance > remoteThreshold,
  };
}
