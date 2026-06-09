import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt, sin, cos, atan2, pi;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../mqtt_client.dart';
import '../models/map_models.dart';
import '../utils/mock_tracking_data.dart';

/// Tracking Service - Handles real-time bus tracking via MQTT
///
/// MQTT Topics:
/// - bus/{busId}/location - Real-time location updates
/// - bus/{busId}/status - Status changes
/// - trip/{tripId}/events - Trip events (arrivals, departures)
/// - geofence/{stopId}/alerts - Geofence alerts
class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  // MQTT Service for real-time updates.
  MqttService? _mqttService;

  // Mock data generator for testing without backend (disabled by default)
  final MockTrackingGenerator _mockGenerator = MockTrackingGenerator();
  bool _useMockData = false; // Set to true only for testing without real GPS

  // Stream controllers
  final Map<String, StreamController<BusLocation>> _locationControllers = {};
  final Map<String, StreamController<GeofenceAlert>> _geofenceControllers = {};
  final StreamController<List<BusLocation>> _allBusesController =
      StreamController<List<BusLocation>>.broadcast();

  // Cached data
  final Map<String, BusLocation> _latestLocations = {};
  final Map<String, RoutePath> _routePaths = {};
  final Map<String, List<RouteStop>> _routeStops = {};

  // Geofencing
  final Set<String> _activeGeofences = {};
  Timer? _geofenceCheckTimer;

  // Subscriptions
  final Map<String, void Function(String topic, String message)>
      _mqttCallbacks = {};

  bool _isInitialized = false;

  /// Initialize the tracking service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _mqttService = MqttService();
      _isInitialized = true;
      _startGeofenceChecker();
      debugPrint('TrackingService: Initialized');
    } catch (e) {
      debugPrint('TrackingService: Initialization error: $e');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _geofenceCheckTimer?.cancel();
    for (final controller in _locationControllers.values) {
      controller.close();
    }
    for (final controller in _geofenceControllers.values) {
      controller.close();
    }
    _allBusesController.close();
    _mqttCallbacks.clear();
  }

  // ==================== BUS TRACKING ====================

  /// Start tracking a specific bus
  Stream<BusLocation> trackBus(String busId) {
    if (!_locationControllers.containsKey(busId)) {
      _locationControllers[busId] = StreamController<BusLocation>.broadcast();

      if (_useMockData) {
        // Use mock data generator
        _mockGenerator.addListener((location) {
          _locationControllers[busId]?.add(location);
        });
        _mockGenerator.startMockMode();
      } else if (_mqttService != null) {
        _subscribeToBusLocation(busId);
      } else {
        debugPrint('TrackingService: MQTT unavailable for bus $busId');
      }
    }
    return _locationControllers[busId]!.stream;
  }

  /// Stop tracking a specific bus
  void stopTrackingBus(String busId) {
    if (_useMockData) {
      _mockGenerator.stopTracking();
    } else {
      _unsubscribeFromBusLocation(busId);
    }
    _locationControllers[busId]?.close();
    _locationControllers.remove(busId);
  }

  /// Get stream of all tracked buses
  Stream<List<BusLocation>> get allBusesStream => _allBusesController.stream;

  /// Get latest location for a bus
  BusLocation? getLatestLocation(String busId) => _latestLocations[busId];

  /// Subscribe to bus location via MQTT
  void _subscribeToBusLocation(String busId) {
    final topics = ['bus/$busId/location', 'driver/$busId/location'];

    for (final topic in topics) {
      if (_mqttCallbacks.containsKey(topic)) continue;

      void callback(String topic, String message) {
        try {
          final payload = jsonDecode(message) as Map<String, dynamic>;
          final location = BusLocation.fromJson(payload);
          _latestLocations[busId] = location;
          _locationControllers[busId]?.add(location);
          _notifyAllBusesUpdate();
          _checkGeofencesForBus(location);
        } catch (e) {
          debugPrint('TrackingService: Error parsing location: $e');
        }
      }

      _mqttCallbacks[topic] = callback;
      final subscription = _mqttService?.subscribe(topic, callback);
      subscription?.catchError((e) {
        debugPrint('TrackingService: MQTT subscribe failed for $topic: $e');
      });
    }
  }

  void _unsubscribeFromBusLocation(String busId) {
    final topics = ['bus/$busId/location', 'driver/$busId/location'];
    for (final topic in topics) {
      final callback = _mqttCallbacks.remove(topic);
      if (callback != null) {
        _mqttService?.unsubscribe(topic, callback);
      }
    }
  }

  void _notifyAllBusesUpdate() {
    if (!_allBusesController.isClosed) {
      _allBusesController.add(_latestLocations.values.toList());
    }
  }

  // ==================== ROUTE TRACKING ====================

  /// Load route path for a trip
  Future<RoutePath?> loadRoutePath(String routeId) async {
    // Check cache first
    if (_routePaths.containsKey(routeId)) {
      return _routePaths[routeId];
    }

    // Use mock data for testing
    if (_useMockData) {
      final mockPath = _mockGenerator.getMockRoutePath();
      _routePaths[routeId] = mockPath;
      return mockPath;
    }

    // TODO: Load from API when backend is ready
    return null;
  }

  /// Load stops for a route
  Future<List<RouteStop>> loadRouteStops(String routeId) async {
    if (_routeStops.containsKey(routeId)) {
      return _routeStops[routeId]!;
    }

    // Use mock data for testing
    if (_useMockData) {
      final mockStops = _mockGenerator.getMockStops();
      _routeStops[routeId] = mockStops;
      return mockStops;
    }

    // TODO: Load from API when backend is ready
    return [];
  }

  /// Cache route data
  void cacheRouteData(String routeId, RoutePath path, List<RouteStop> stops) {
    _routePaths[routeId] = path;
    _routeStops[routeId] = stops;
  }

  // ==================== GEOFENCING ====================

  /// Start monitoring geofences for a stop
  Stream<GeofenceAlert> monitorGeofence(
    String stopId,
    String stopName,
    LatLng stopPosition,
  ) {
    if (!_geofenceControllers.containsKey(stopId)) {
      _geofenceControllers[stopId] =
          StreamController<GeofenceAlert>.broadcast();
    }

    _activeGeofences.add(stopId);
    _geofencePositions[stopId] = stopPosition;
    _geofenceNames[stopId] = stopName;

    return _geofenceControllers[stopId]!.stream;
  }

  /// Stop monitoring a geofence
  void stopMonitoringGeofence(String stopId) {
    _activeGeofences.remove(stopId);
    _geofencePositions.remove(stopId);
    _geofenceNames.remove(stopId);
    _geofenceControllers[stopId]?.close();
    _geofenceControllers.remove(stopId);
  }

  final Map<String, LatLng> _geofencePositions = {};
  final Map<String, String> _geofenceNames = {};
  final Map<String, DateTime> _lastAlertTimes = {};

  void _startGeofenceChecker() {
    _geofenceCheckTimer?.cancel();
    _geofenceCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAllGeofences();
    });
  }

  void _checkAllGeofences() {
    for (final location in _latestLocations.values) {
      _checkGeofencesForBus(location);
    }
  }

  void _checkGeofencesForBus(BusLocation busLocation) {
    for (final stopId in _activeGeofences) {
      final stopPosition = _geofencePositions[stopId];
      if (stopPosition == null) continue;

      final distance = calculateDistance(busLocation.position, stopPosition);
      final eta = estimateTime(distance, busLocation.speed);

      // Check if we should send an alert
      GeofenceType? alertType;

      if (distance <= 100) {
        alertType = GeofenceType.arrived;
      } else if (distance <= 500 && eta <= 60) {
        alertType = GeofenceType.arriving;
      } else if (distance <= 2000 && eta <= 300) {
        // 5 minutes
        alertType = GeofenceType.approaching;
      }

      if (alertType != null) {
        _sendGeofenceAlert(
          busId: busLocation.busId,
          stopId: stopId,
          stopName: _geofenceNames[stopId] ?? 'Stop',
          type: alertType,
          distance: distance,
          etaSeconds: eta,
        );
      }
    }
  }

  void _sendGeofenceAlert({
    required String busId,
    required String stopId,
    required String stopName,
    required GeofenceType type,
    required double distance,
    required int etaSeconds,
  }) {
    // Rate limit alerts (don't send same alert within 2 minutes)
    final alertKey = '${busId}_${stopId}_${type.name}';
    final lastAlert = _lastAlertTimes[alertKey];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes < 2) {
      return;
    }

    final alert = GeofenceAlert(
      id: '${DateTime.now().millisecondsSinceEpoch}_$alertKey',
      busId: busId,
      stopId: stopId,
      stopName: stopName,
      type: type,
      distance: distance,
      etaSeconds: etaSeconds,
      timestamp: DateTime.now(),
    );

    _lastAlertTimes[alertKey] = DateTime.now();
    _geofenceControllers[stopId]?.add(alert);

    // TODO: Publish to MQTT when backend is ready
    // _mqttService?.publish('geofence/$stopId/alerts', alert.toJson());
  }

  // ==================== UTILITY METHODS ====================

  /// Calculate distance between two points in meters (Haversine formula)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters

    final lat1Rad = point1.latitude * pi / 180;
    final lat2Rad = point2.latitude * pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Estimate time to reach destination in seconds
  static int estimateTime(double distanceMeters, double speedKmh) {
    if (speedKmh <= 0) return 9999;
    final speedMs = speedKmh / 3.6;
    return (distanceMeters / speedMs).round();
  }

  /// Get bearing between two points (for rotating bus marker)
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final lng1 = from.longitude * pi / 180;
    final lng2 = to.longitude * pi / 180;

    final y = sin(lng2 - lng1) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lng2 - lng1);

    var bearing = atan2(y, x) * 180 / pi;
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  static bool isInGeofence(LatLng point, LatLng center, double radiusMeters) {
    return calculateDistance(point, center) <= radiusMeters;
  }
}

/// Extension for GeofenceAlert JSON serialization
extension GeofenceAlertJson on GeofenceAlert {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'busId': busId,
      'stopId': stopId,
      'stopName': stopName,
      'type': type.name,
      'distance': distance,
      'etaSeconds': etaSeconds,
      'timestamp': timestamp.toIso8601String(),
      'isDismissed': isDismissed,
    };
  }
}
