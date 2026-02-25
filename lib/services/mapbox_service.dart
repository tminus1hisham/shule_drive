import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/map_config.dart';

/// Mapbox Service - Handles Mapbox API interactions
/// 
/// Features:
/// - Route directions between waypoints
/// - Distance and duration calculations
/// - Reverse geocoding (coordinates to address)
/// - Polyline decoding
class MapboxService {
  static final MapboxService _instance = MapboxService._internal();
  
  factory MapboxService() => _instance;
  
  MapboxService._internal();

  final String _accessToken = MapConfig.mapboxAccessToken;
  
  /// Get route between multiple waypoints
  /// 
  /// Returns a [RouteResult] containing:
  /// - List of coordinates (decoded polyline)
  /// - Distance in meters
  /// - Duration in seconds
  /// - Raw geometry string
  /// 
  /// Example waypoints: [{'lat': -1.28, 'lng': 36.82}, {'lat': -1.29, 'lng': 36.83}]
  Future<RouteResult> getRoute(List<Map<String, double>> waypoints) async {
    if (_accessToken.isEmpty) {
      return RouteResult.failure('Mapbox access token not configured');
    }

    if (waypoints.length < 2) {
      return RouteResult.failure('At least 2 waypoints required');
    }

    try {
      // Build coordinates string: lng,lat;lng,lat;...
      final coordinates = waypoints.map((wp) {
        final lat = wp['lat'] ?? wp['latitude'];
        final lng = wp['lng'] ?? wp['longitude'];
        return '$lng,$lat';
      }).join(';');

      final url = Uri.parse(
        '${MapConfig.directionsUrl}/$coordinates'
        '?access_token=$_accessToken'
        '&geometries=polyline'
        '&overview=full'
        '&steps=false'
        '&alternatives=false',
      );

      debugPrint('🗺️ Fetching route from Mapbox...');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          return RouteResult.failure('No route found');
        }

        final route = data['routes'][0];
        final geometry = route['geometry'] as String;
        final distance = (route['distance'] as num).toDouble(); // in meters
        final duration = (route['duration'] as num).toDouble(); // in seconds

        // Decode polyline to coordinates
        final coordinates = _decodePolyline(geometry);

        debugPrint('✅ Route found: ${distance.toStringAsFixed(0)}m, ${duration.toStringAsFixed(0)}s');

        return RouteResult.success(
          coordinates: coordinates,
          distance: distance,
          duration: duration,
          geometry: geometry,
        );
      } else {
        final error = jsonDecode(response.body);
        return RouteResult.failure(
          error['message'] ?? 'Failed to get route (${response.statusCode})',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Mapbox route error: $e');
      debugPrint(stackTrace.toString());
      return RouteResult.failure('Network error: ${e.toString()}');
    }
  }

  /// Get distance and duration between two points
  /// 
  /// Returns distance in meters and duration in seconds
  Future<Map<String, double>> getDistanceAndDuration(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final result = await getRoute([
      {'lat': startLat, 'lng': startLng},
      {'lat': endLat, 'lng': endLng},
    ]);

    if (result.success) {
      return {
        'distance': result.distance,
        'duration': result.duration,
      };
    }

    // Fallback to straight-line distance if API fails
    final distance = _calculateStraightLineDistance(
      startLat, startLng, endLat, endLng,
    );
    
    return {
      'distance': distance,
      'duration': distance / 8.33, // Assume 30 km/h average speed
    };
  }

  /// Reverse geocode - get address from coordinates
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    if (_accessToken.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse(
        '${MapConfig.geocodingUrl}/$longitude,$latitude.json'
        '?access_token=$_accessToken'
        '&types=address,place,locality'
        '&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          final placeName = features[0]['place_name'] as String;
          return placeName;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
      return null;
    }
  }

  /// Decode Mapbox polyline (precision 5)
  List<MapPosition> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];

    final List<MapPosition> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(MapPosition(lng / 1E5, lat / 1E5));
    }

    return points;
  }

  /// Calculate straight-line distance between two coordinates (Haversine formula)
  double _calculateStraightLineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final deltaLat = _toRadians(lat2 - lat1);
    final deltaLon = _toRadians(lon2 - lon1);

    final a = (deltaLat / 2).sin() * (deltaLat / 2).sin() +
              lat1Rad.cos() * lat2Rad.cos() *
              (deltaLon / 2).sin() * (deltaLon / 2).sin();
    
    final c = 2 * a.sqrt().atan2((1 - a).sqrt(), a.sqrt());
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
}

/// Extension for double math operations
extension _DoubleMath on double {
  double sin() => DartMath.sin(this);
  double cos() => DartMath.cos(this);
  double sqrt() => DartMath.sqrt(this);
  double atan2(double y, double x) => DartMath.atan2(y, x);
}

/// Dart math functions
class DartMath {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
  static double sqrt(double x) => _sqrt(x);
  static double atan2(double y, double x) => _atan2(y, x);
  
  static double _sin(double x) {
    // Simple Taylor series approximation
    x = x % (2 * 3.14159265359);
    double result = x;
    double term = x;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
  
  static double _cos(double x) {
    x = x % (2 * 3.14159265359);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }
  
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  
  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0) return y >= 0 ? _atan(y / x) + 3.14159265359 : _atan(y / x) - 3.14159265359;
    return y > 0 ? 3.14159265359 / 2 : (y < 0 ? -3.14159265359 / 2 : 0);
  }
  
  static double _atan(double x) {
    // Taylor series for atan
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}

/// Route Result class
class RouteResult {
  final bool success;
  final List<MapPosition>? coordinates;
  final double distance; // in meters
  final double duration; // in seconds
  final String? geometry;
  final String? errorMessage;

  RouteResult._({
    required this.success,
    this.coordinates,
    this.distance = 0,
    this.duration = 0,
    this.geometry,
    this.errorMessage,
  });

  factory RouteResult.success({
    required List<MapPosition> coordinates,
    required double distance,
    required double duration,
    required String geometry,
  }) {
    return RouteResult._(
      success: true,
      coordinates: coordinates,
      distance: distance,
      duration: duration,
      geometry: geometry,
    );
  }

  factory RouteResult.failure(String message) {
    return RouteResult._(
      success: false,
      errorMessage: message,
    );
  }

  /// Get formatted distance (e.g., "2.5 km" or "500 m")
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  /// Get formatted duration (e.g., "5 min" or "1h 30m")
  String get formattedDuration {
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMins}m';
  }

  @override
  String toString() => success
      ? 'RouteResult: $formattedDistance, $formattedDuration'
      : 'RouteResult: Error - $errorMessage';
}

/// Map Position class for coordinates
class MapPosition {
  final double longitude;
  final double latitude;

  MapPosition(this.longitude, this.latitude);

  @override
  String toString() => 'MapPosition($latitude, $longitude)';
}
