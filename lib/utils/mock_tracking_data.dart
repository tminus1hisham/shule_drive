import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

/// Mock Tracking Data Generator - For testing without real MQTT backend
class MockTrackingGenerator {
  static final MockTrackingGenerator _instance =
      MockTrackingGenerator._internal();
  factory MockTrackingGenerator() => _instance;
  MockTrackingGenerator._internal();

  Timer? _locationTimer;
  final List<Function(BusLocation)> _listeners = [];

  // Mock route coordinates (example: around Nairobi)
  final List<LatLng> _routePoints = [
    LatLng(-1.286389, 36.817223), // CBD
    LatLng(-1.280000, 36.820000),
    LatLng(-1.275000, 36.825000),
    LatLng(-1.270000, 36.830000),
    LatLng(-1.265000, 36.835000), // Karen area
    LatLng(-1.260000, 36.840000),
  ];

  int _currentPointIndex = 0;
  bool _isMoving = false;

  // Mock bus data
  final String busId = 'BUS001';
  final String busNumber = 'KCA 123X';
  final String driverName = 'John Kamau';
  final String driverPhone = '+254712345678';

  /// Start generating mock location updates
  void startTracking() {
    if (_isMoving) return;

    _isMoving = true;
    _currentPointIndex = 0;

    // Generate location every 3 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _generateNextLocation();
    });
  }

  /// Stop generating mock data
  void stopTracking() {
    _isMoving = false;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Listen to mock location updates
  void addListener(Function(BusLocation) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(BusLocation) listener) {
    _listeners.remove(listener);
  }

  /// Returns a stream of mock bus locations
  Stream<BusLocation> trackBus(String busId) {
    // Create a stream controller that emits locations
    final controller = StreamController<BusLocation>.broadcast();

    void listener(BusLocation location) {
      if (!controller.isClosed) {
        controller.add(location);
      }
    }

    addListener(listener);

    // Clean up when stream is cancelled
    controller.onCancel = () {
      removeListener(listener);
      controller.close();
    };

    return controller.stream;
  }

  void _generateNextLocation() {
    if (_currentPointIndex >= _routePoints.length - 1) {
      _currentPointIndex = 0; // Loop back
    }

    final currentPos = _routePoints[_currentPointIndex];
    final nextPos = _routePoints[_currentPointIndex + 1];

    // Calculate heading
    final heading = _calculateBearing(currentPos, nextPos);

    // Calculate distance and ETA
    final distance = _calculateDistance(currentPos, nextPos);
    const speed = 30.0; // km/h
    final eta = (distance / (speed * 1000 / 3600)).round();

    final location = BusLocation(
      busId: busId,
      busNumber: busNumber,
      position: currentPos,
      heading: heading,
      speed: speed,
      timestamp: DateTime.now(),
      driverName: driverName,
      driverPhone: driverPhone,
      status: BusStatus.active,
      passengerCount: 15,
      nextStopId: 'STOP_${_currentPointIndex + 2}',
      distanceToNextStop: distance,
      etaToNextStop: eta,
    );

    // Notify listeners
    for (final listener in _listeners) {
      listener(location);
    }

    _currentPointIndex++;
  }

  /// Get mock stops for the route
  List<RouteStop> getMockStops() {
    return [
      RouteStop(
        id: 'STOP_1',
        name: 'Nairobi CBD',
        position: LatLng(-1.286389, 36.817223),
        address: 'Kenyatta Avenue',
        order: 1,
        type: StopType.pickup,
        studentIds: ['STU001', 'STU002'],
      ),
      RouteStop(
        id: 'STOP_2',
        name: 'Westlands',
        position: LatLng(-1.268264, 36.808945),
        address: 'Waiyaki Way',
        order: 2,
        type: StopType.pickup,
        studentIds: ['STU003', 'STU004'],
      ),
      RouteStop(
        id: 'STOP_3',
        name: 'Karen',
        position: LatLng(-1.319167, 36.711389),
        address: 'Karen Road',
        order: 3,
        type: StopType.dropoff,
        studentIds: ['STU005', 'STU006'],
      ),
      RouteStop(
        id: 'STOP_4',
        name: 'Rongai',
        position: LatLng(-1.396111, 36.763056),
        address: 'Magadi Road',
        order: 4,
        type: StopType.dropoff,
        studentIds: ['STU007', 'STU008'],
      ),
    ];
  }

  /// Get mock route path
  RoutePath getMockRoutePath() {
    return RoutePath(
      id: 'ROUTE_001',
      name: 'CBD to Rongai',
      polyline: [
        LatLng(-1.286389, 36.817223),
        LatLng(-1.280000, 36.820000),
        LatLng(-1.275000, 36.825000),
        LatLng(-1.270000, 36.830000),
        LatLng(-1.268264, 36.808945),
        LatLng(-1.319167, 36.711389),
        LatLng(-1.396111, 36.763056),
      ],
      distance: 25.5,
      duration: 45,
    );
  }

  /// Generate a mock geofence alert
  GeofenceAlert generateMockAlert(GeofenceType type) {
    return GeofenceAlert(
      id: 'ALERT_${DateTime.now().millisecondsSinceEpoch}',
      busId: busId,
      stopId: 'STOP_2',
      stopName: 'Westlands',
      type: type,
      distance: type == GeofenceType.approaching
          ? 2000
          : type == GeofenceType.arriving
          ? 500
          : 100,
      etaSeconds: type == GeofenceType.approaching
          ? 300
          : type == GeofenceType.arriving
          ? 60
          : 0,
      timestamp: DateTime.now(),
    );
  }

  // Helper methods
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final lat1Rad = p1.latitude * pi / 180;
    final lat2Rad = p2.latitude * pi / 180;
    final deltaLat = (p2.latitude - p1.latitude) * pi / 180;
    final deltaLng = (p2.longitude - p1.longitude) * pi / 180;

    final a =
        (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _calculateBearing(LatLng from, LatLng to) {
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
}

/// Extension to add mock mode to TrackingService
extension MockTrackingService on MockTrackingGenerator {
  /// Start mock tracking mode
  void startMockMode() {
    startTracking();
  }

  /// Get current mock location
  BusLocation? get currentMockLocation {
    if (_currentPointIndex < _routePoints.length) {
      return BusLocation(
        busId: busId,
        busNumber: busNumber,
        position: _routePoints[_currentPointIndex],
        heading: 0,
        speed: 30,
        timestamp: DateTime.now(),
        driverName: driverName,
        driverPhone: driverPhone,
        status: BusStatus.active,
        passengerCount: 15,
        nextStopId: 'STOP_${_currentPointIndex + 1}',
      );
    }
    return null;
  }
}
