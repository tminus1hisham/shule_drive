import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/tracking_service.dart';

/// Tracking Provider - Manages real-time bus tracking state
class TrackingProvider extends ChangeNotifier {
  final TrackingService _trackingService = TrackingService();

  // State
  MapViewState _viewState = MapViewState.loading;
  MapViewState get viewState => _viewState;

  // Selected trip/bus
  String? _selectedTripId;
  String? get selectedTripId => _selectedTripId;

  String? _selectedBusId;
  String? get selectedBusId => _selectedBusId;

  // Location data
  BusLocation? _currentBusLocation;
  BusLocation? get currentBusLocation => _currentBusLocation;

  List<RouteStop> _stops = [];
  List<RouteStop> get stops => _stops;

  RoutePath? _routePath;
  RoutePath? get routePath => _routePath;

  // Map markers and polylines
  final List<Marker> _markers = [];
  List<Marker> get markers => _markers;

  final List<Polyline> _polylines = [];
  List<Polyline> get polylines => _polylines;

  // Geofence alerts
  final List<GeofenceAlert> _alerts = [];
  List<GeofenceAlert> get alerts => List.unmodifiable(_alerts);

  // Map controller
  MapController? _mapController;
  MapController? get mapController => _mapController;

  // Stream subscriptions
  StreamSubscription<BusLocation>? _locationSubscription;
  StreamSubscription<GeofenceAlert>? _geofenceSubscription;

  // Settings
  bool _followBus = true;
  bool get followBus => _followBus;

  String _mapType = 'normal';
  String get mapType => _mapType;

  bool _showTraffic = false;
  bool get showTraffic => _showTraffic;

  /// Initialize the provider
  Future<void> initialize() async {
    _viewState = MapViewState.loading;
    notifyListeners();

    try {
      await _trackingService.initialize();
      _viewState = MapViewState.ready;
    } catch (e) {
      _viewState = MapViewState.error;
      debugPrint('TrackingProvider: Initialization error: $e');
    }

    notifyListeners();
  }

  /// Start tracking a specific trip
  Future<void> startTrackingTrip({
    required String tripId,
    required String busId,
    String? routeId,
  }) async {
    _selectedTripId = tripId;
    _selectedBusId = busId;
    _viewState = MapViewState.loading;
    notifyListeners();

    // Stop previous tracking
    await stopTracking();

    try {
      // Load route data if routeId provided
      if (routeId != null) {
        _routePath = await _trackingService.loadRoutePath(routeId);
        _stops = await _trackingService.loadRouteStops(routeId);
        _updatePolylines();
        _updateStopMarkers();
      }

      // Start listening to bus location
      _locationSubscription = _trackingService
          .trackBus(busId)
          .listen(
            _onLocationUpdate,
            onError: (error) {
              debugPrint('TrackingProvider: Location stream error: $error');
            },
          );

      // Monitor geofences for all stops
      for (final stop in _stops) {
        _geofenceSubscription = _trackingService
            .monitorGeofence(stop.id, stop.name, stop.position)
            .listen(_onGeofenceAlert);
      }

      _viewState = MapViewState.ready;
    } catch (e) {
      _viewState = MapViewState.error;
      debugPrint('TrackingProvider: Start tracking error: $e');
    }

    notifyListeners();
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();
    await _geofenceSubscription?.cancel();
    _locationSubscription = null;
    _geofenceSubscription = null;

    if (_selectedBusId != null) {
      _trackingService.stopTrackingBus(_selectedBusId!);
    }

    for (final stop in _stops) {
      _trackingService.stopMonitoringGeofence(stop.id);
    }
  }

  /// Handle location updates
  void _onLocationUpdate(BusLocation location) {
    _currentBusLocation = location;
    _updateBusMarker();

    if (_followBus && _mapController != null) {
      _mapController!.move(location.position, _mapController!.camera.zoom);
    }

    notifyListeners();
  }

  /// Handle geofence alerts
  void _onGeofenceAlert(GeofenceAlert alert) {
    // Add to alerts list
    _alerts.insert(0, alert);

    // Keep only last 10 alerts
    if (_alerts.length > 10) {
      _alerts.removeLast();
    }

    notifyListeners();
  }

  /// Update bus marker on map
  void _updateBusMarker() {
    if (_currentBusLocation == null) return;

    final marker = Marker(
      key: ValueKey('bus_$_selectedBusId'),
      point: _currentBusLocation!.position,
      width: 40,
      height: 40,
      child: Transform.rotate(
        angle: _currentBusLocation!.heading * (3.14159 / 180),
        child: const Text('🚌', style: TextStyle(fontSize: 28)),
      ),
    );

    _markers.removeWhere((m) => m.key == ValueKey('bus_$_selectedBusId'));
    _markers.add(marker);
  }

  /// Update stop markers on map
  void _updateStopMarkers() {
    for (final stop in _stops) {
      final isNextStop = stop.id == _currentBusLocation?.nextStopId;

      final marker = Marker(
        key: ValueKey('stop_${stop.id}'),
        point: stop.position,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: isNextStop ? Colors.blue : Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      );

      _markers.removeWhere((m) => m.key == ValueKey('stop_${stop.id}'));
      _markers.add(marker);
    }
  }

  /// Update route polylines
  void _updatePolylines() {
    if (_routePath == null || _routePath!.polyline.isEmpty) return;

    final polyline = Polyline(
      points: _routePath!.polyline,
      color: const Color(0xFF6B9B5B),
      strokeWidth: 5,
    );

    _polylines.clear();
    _polylines.add(polyline);
  }

  /// Set map controller
  void setMapController(MapController controller) {
    _mapController = controller;
  }

  /// Center map on bus
  Future<void> centerOnBus() async {
    if (_mapController != null && _currentBusLocation != null) {
      _mapController!.move(_currentBusLocation!.position, 16);
    }
  }

  /// Toggle follow bus mode
  void toggleFollowBus() {
    _followBus = !_followBus;
    if (_followBus) {
      centerOnBus();
    }
    notifyListeners();
  }

  /// Toggle map type
  void toggleMapType() {
    _mapType = _mapType == 'normal' ? 'satellite' : 'normal';
    notifyListeners();
  }

  /// Toggle traffic layer
  void toggleTraffic() {
    _showTraffic = !_showTraffic;
    notifyListeners();
  }

  /// Dismiss an alert
  void dismissAlert(String alertId) {
    _alerts.removeWhere((a) => a.id == alertId);
    notifyListeners();
  }

  /// Clear all alerts
  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  /// Get ETA for a specific stop
  String? getEtaForStop(String stopId) {
    if (_currentBusLocation?.nextStopId != stopId) return null;
    return _currentBusLocation?.formattedEta;
  }

  /// Get formatted trip info
  Map<String, dynamic>? get tripInfo {
    if (_currentBusLocation == null) return null;

    return {
      'busNumber': _currentBusLocation!.busNumber,
      'driverName': _currentBusLocation!.driverName ?? 'Unknown',
      'status': _currentBusLocation!.status.displayName,
      'speed': '${_currentBusLocation!.speed.toStringAsFixed(0)} km/h',
      'nextStop': _stops
          .where((s) => s.id == _currentBusLocation!.nextStopId)
          .firstOrNull
          ?.name,
      'eta': _currentBusLocation!.formattedEta,
      'passengers': _currentBusLocation!.passengerCount ?? 0,
    };
  }

  @override
  void dispose() {
    stopTracking();
    _mapController?.dispose();
    super.dispose();
  }
}
