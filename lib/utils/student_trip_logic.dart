import 'dart:math' show atan2, cos, min, pi, sin, sqrt;

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

typedef GeoPoint = ({double lat, double lng});

/// Metres from [p] to the closest point on [line]. Flat-earth projection
/// around [p]: accurate to well under a metre at off-route scales (~50 m).
double distanceToPolylineMeters(GeoPoint p, List<GeoPoint> line) {
  if (line.isEmpty) return double.infinity;
  const metersPerDegLat = 111320.0;
  final metersPerDegLng = metersPerDegLat * cos(p.lat * pi / 180);
  (double, double) xy(GeoPoint q) =>
      ((q.lng - p.lng) * metersPerDegLng, (q.lat - p.lat) * metersPerDegLat);

  if (line.length == 1) {
    final (x, y) = xy(line.first);
    return sqrt(x * x + y * y);
  }
  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    final (ax, ay) = xy(line[i]);
    final (bx, by) = xy(line[i + 1]);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    // Projection of p (the origin) onto segment a-b, clamped to the segment.
    final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    best = min(best, sqrt(cx * cx + cy * cy));
  }
  return best;
}

/// Visit order for [stops]: always the closest remaining one next.
// ponytail: greedy, not an optimal tour. Use the Mapbox Optimization API if
// drivers report silly orders on long routes.
List<T> orderNearestFirst<T>(
  GeoPoint start,
  Iterable<T> stops,
  GeoPoint Function(T stop) at,
) {
  final remaining = stops.toList();
  final ordered = <T>[];
  var here = start;
  while (remaining.isNotEmpty) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < remaining.length; i++) {
      final there = at(remaining[i]);
      final d = calculateStudentDistanceMeters(
        vehicleLatitude: here.lat,
        vehicleLongitude: here.lng,
        targetLatitude: there.lat,
        targetLongitude: there.lng,
      );
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    final next = remaining.removeAt(bestIndex);
    ordered.add(next);
    here = at(next);
  }
  return ordered;
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
