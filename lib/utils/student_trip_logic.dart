import 'dart:math' show atan2, cos, pi, sin, sqrt;

/// How close the bus gets before the driver is prompted to pick/drop.
const double studentProximityThresholdMeters = 200;

enum StudentTripActionMode { pickup, dropoff }

double calculateStudentDistanceMeters({
  required double vehicleLatitude,
  required double vehicleLongitude,
  required double targetLatitude,
  required double targetLongitude,
}) {
  const earthRadiusMeters = 6371000.0;

  final lat1Rad = vehicleLatitude * pi / 180;
  final lat2Rad = targetLatitude * pi / 180;
  final deltaLat = (targetLatitude - vehicleLatitude) * pi / 180;
  final deltaLng = (targetLongitude - vehicleLongitude) * pi / 180;

  final a =
      sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMeters * c;
}

bool isWithinStudentProximity(double distanceMeters) {
  return distanceMeters <= studentProximityThresholdMeters;
}

/// "150 m" / "1.2 km".
String formatStudentDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

/// The item with the smallest known distance, or null if none is known.
T? nearestBy<T>(Iterable<T> items, double? Function(T item) distanceOf) {
  T? best;
  double? bestDistance;
  for (final item in items) {
    final d = distanceOf(item);
    if (d != null && (bestDistance == null || d < bestDistance)) {
      best = item;
      bestDistance = d;
    }
  }
  return best;
}

bool hasValidStudentCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  return latitude != 0 && longitude != 0;
}

bool isReturnTripDirection(String? tripDirection) {
  final value = tripDirection?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;

  return value == 'dropoff' ||
      value == 'drop_off' ||
      value == 'drop-off' ||
      value == 'from_school' ||
      value == 'return' ||
      value == 'home';
}

String normalizeGuardianPhone(String? phone) {
  return phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
}
