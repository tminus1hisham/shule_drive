import 'dart:math' show atan2, cos, pi, sin, sqrt;

const double studentProximityThresholdMeters = 100;

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

