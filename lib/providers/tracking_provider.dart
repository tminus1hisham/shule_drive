import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/tracking_service.dart';
import '../api/services/trip_service.dart';

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

  // Trip data from API
  Trip? _trip;

  // Location data
  BusLocation? _currentBusLocation;
  BusLocation? get currentBusLocation => _currentBusLocation;

  List<RouteStop> _stops = [];
  List<RouteStop> get stops => _stops;

  // Geofence alerts
  final List<GeofenceAlert> _alerts = [];
  List<GeofenceAlert> get alerts => List.unmodifiable(_alerts);

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

  // Camera control — screen checks this flag and calls clearCenterRequest() after acting
  bool _shouldCenterOnBus = false;
  bool get shouldCenterOnBus => _shouldCenterOnBus;

  void clearCenterRequest() {
    _shouldCenterOnBus = false;
  }

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
      // Load trip details from API to populate stops and trip info
      final trip = await TripService().getTripDetails(tripId);
      if (trip != null) {
        _trip = trip;
        _stops = trip.stops
            .where((s) =>
                s.latitude != null &&
                s.longitude != null &&
                s.latitude != 0 &&
                s.longitude != 0)
            .map(
              (s) => RouteStop(
                id: s.id,
                name: s.name,
                position: LatLng(s.latitude!, s.longitude!),
                address: s.address,
                order: s.order,
                type: StopType.fromString(s.type ?? 'pickup'),
                studentIds: [],
              ),
            )
            .toList();
      }

      // Start listening to bus location via MQTT
      _locationSubscription = _trackingService.trackBus(busId).listen(
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
    _shouldCenterOnBus = _followBus;
    notifyListeners();
  }

  /// Handle geofence alerts
  void _onGeofenceAlert(GeofenceAlert alert) {
    _alerts.insert(0, alert);
    if (_alerts.length > 10) {
      _alerts.removeLast();
    }
    notifyListeners();
  }

  /// Center map on bus (sets flag; screen reacts via listener)
  Future<void> centerOnBus() async {
    _shouldCenterOnBus = true;
    notifyListeners();
  }

  /// Toggle follow bus mode
  void toggleFollowBus() {
    _followBus = !_followBus;
    if (_followBus) {
      _shouldCenterOnBus = true;
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
    if (_trip == null && _currentBusLocation == null) return null;

    return {
      'busNumber':
          _currentBusLocation?.busNumber ??
          _trip?.vehicleNumber ??
          _trip?.vehicleId ??
          '',
      'driverName': _currentBusLocation?.driverName ?? 'Driver',
      'status': _currentBusLocation?.status.displayName ??
          (_trip?.status == 'active' ? 'Active' : 'Idle'),
      'speed': _currentBusLocation != null
          ? '${_currentBusLocation!.speed.toStringAsFixed(0)} km/h'
          : '-- km/h',
      'nextStop': _currentBusLocation != null
          ? _stops
                .where((s) => s.id == _currentBusLocation!.nextStopId)
                .firstOrNull
                ?.name
          : _stops.isNotEmpty
          ? _stops.first.name
          : null,
      'eta': _currentBusLocation?.formattedEta,
      'passengers':
          _currentBusLocation?.passengerCount ??
          (_trip?.students.length ?? 0),
    };
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
