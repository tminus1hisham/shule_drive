import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'notification_service.dart';
import 'local_database_service.dart';
import '../api/services/trip_service.dart' as api;

/// Geofence Notification Handler
/// 
/// Monitors bus location relative to pickup stops and triggers notifications
/// at three distances: 2km (approaching), 500m (arriving), 100m (arrived)
class GeofenceNotificationHandler {
  static final GeofenceNotificationHandler _instance = GeofenceNotificationHandler._internal();
  factory GeofenceNotificationHandler() => _instance;
  GeofenceNotificationHandler._internal();

  final NotificationService _notificationService = NotificationService();
  final LocalDatabaseService _db = LocalDatabaseService();

  // Geofence thresholds
  static const double _approachingDistance = 2000; // 2km
  static const double _arrivingDistance = 500;     // 500m
  static const double _arrivedDistance = 100;      // 100m

  // Cooldown periods to prevent spam
  static const Duration _approachingCooldown = Duration(minutes: 5);
  static const Duration _arrivingCooldown = Duration(minutes: 2);
  static const Duration _arrivedCooldown = Duration(minutes: 1);

  // Track triggered alerts for cooldown
  final Map<String, DateTime> _lastAlertTimes = {};
  
  // Stream subscription for tracking
  StreamSubscription<LatLng>? _trackingSubscription;
  
  // Current trip and stops being monitored
  api.Trip? _currentTrip;
  List<api.TripStop> _monitoredStops = [];
  Map<String, List<String>> _stopToStudents = {}; // stopId -> studentIds
  
  bool _isMonitoring = false;

  /// Start monitoring geofences for a trip
  Future<void> startMonitoring(api.Trip trip, {List<String>? studentIds}) async {
    if (_isMonitoring) {
      await stopMonitoring();
    }

    _currentTrip = trip;
    _monitoredStops = trip.stops.where((stop) => 
      stop.latitude != null && stop.longitude != null
    ).toList();

    // Map stops to students (for guardian-specific notifications)
    _buildStopToStudentMap(trip, studentIds);

    _isMonitoring = true;

    if (kDebugMode) {
      print('🔔 Geofence monitoring started for trip: ${trip.id}');
      print('   Monitored stops: ${_monitoredStops.length}');
    }

    // Subscribe to FCM topic for this trip
    await _notificationService.subscribeToTrip(trip.id);
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (_currentTrip != null) {
      await _notificationService.unsubscribeFromTrip(_currentTrip!.id);
    }

    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _currentTrip = null;
    _monitoredStops = [];
    _stopToStudents = {};
    _lastAlertTimes.clear();
    _isMonitoring = false;

    if (kDebugMode) {
      print('🔔 Geofence monitoring stopped');
    }
  }

  /// Build mapping of stops to students
  void _buildStopToStudentMap(api.Trip trip, List<String>? filterStudentIds) {
    _stopToStudents = {};

    for (final student in trip.students) {
      // Skip if filtering and student not in list
      if (filterStudentIds != null && !filterStudentIds.contains(student.id)) {
        continue;
      }

      // Find the stop for this student (by pickup location logic)
      // In real implementation, student would have a stop_id reference
      final stopIndex = trip.students.indexOf(student);
      if (stopIndex < trip.stops.length) {
        final stopId = trip.stops[stopIndex].id;
        _stopToStudents.putIfAbsent(stopId, () => []);
        _stopToStudents[stopId]!.add(student.id);
      }
    }
  }

  /// Process bus location update
  /// Call this when bus location updates from GPS/MQTT
  Future<void> processLocationUpdate(LatLng busLocation, {double? speedKmh}) async {
    if (!_isMonitoring || _currentTrip == null) return;

    for (final stop in _monitoredStops) {
      if (stop.latitude == null || stop.longitude == null) continue;

      final stopLocation = LatLng(stop.latitude!, stop.longitude!);
      final distance = _calculateDistance(busLocation, stopLocation);

      // Calculate ETA based on speed
      final etaMinutes = speedKmh != null && speedKmh > 0
          ? (distance / 1000 / speedKmh * 60).round()
          : _estimateEtaFromDistance(distance);

      // Determine alert type
      GeofenceAlertType? alertType;
      
      if (distance <= _arrivedDistance) {
        alertType = GeofenceAlertType.arrived;
      } else if (distance <= _arrivingDistance) {
        alertType = GeofenceAlertType.arriving;
      } else if (distance <= _approachingDistance) {
        alertType = GeofenceAlertType.approaching;
      }

      if (alertType != null) {
        final alertKey = '${_currentTrip!.id}_${stop.id}_${alertType.name}';
        
        if (_shouldTriggerAlert(alertKey, alertType)) {
          await _triggerAlert(
            tripId: _currentTrip!.id,
            stop: stop,
            alertType: alertType,
            distance: distance,
            etaMinutes: etaMinutes,
            busLocation: busLocation,
          );
          
          _lastAlertTimes[alertKey] = DateTime.now();
        }
      }
    }
  }

  /// Check if alert should be triggered (cooldown logic)
  bool _shouldTriggerAlert(String alertKey, GeofenceAlertType type) {
    final lastTime = _lastAlertTimes[alertKey];
    if (lastTime == null) return true;

    final cooldown = switch (type) {
      GeofenceAlertType.approaching => _approachingCooldown,
      GeofenceAlertType.arriving => _arrivingCooldown,
      GeofenceAlertType.arrived => _arrivedCooldown,
    };

    return DateTime.now().difference(lastTime) > cooldown;
  }

  /// Trigger geofence alert
  Future<void> _triggerAlert({
    required String tripId,
    required api.TripStop stop,
    required GeofenceAlertType alertType,
    required double distance,
    required int etaMinutes,
    required LatLng busLocation,
  }) async {
    final studentIds = _stopToStudents[stop.id] ?? [];

    if (kDebugMode) {
      print('🔔 Geofence alert triggered:');
      print('   Type: ${alertType.name}');
      print('   Stop: ${stop.name}');
      print('   Distance: ${distance.toStringAsFixed(0)}m');
      print('   ETA: $etaMinutes min');
    }

    // Save to local database
    final alertId = await _db.saveGeofenceAlert(
      tripId: tripId,
      alertType: alertType.name,
      distanceMeters: distance,
      etaMinutes: etaMinutes,
      latitude: busLocation.latitude,
      longitude: busLocation.longitude,
      sentNotification: false,
    );

    // Show local notification
    final title = switch (alertType) {
      GeofenceAlertType.approaching => '🚌 Bus Approaching',
      GeofenceAlertType.arriving => '🚌 Bus Arriving Soon',
      GeofenceAlertType.arrived => '🛑 Bus Has Arrived',
    };

    String body;
    if (alertType == GeofenceAlertType.arrived) {
      body = 'The bus has arrived at ${stop.name}';
    } else if (etaMinutes > 0) {
      body = 'Bus is approximately $etaMinutes minutes away from ${stop.name}';
    } else {
      final dist = distance < 1000 
          ? '${distance.toInt()}m' 
          : '${(distance / 1000).toStringAsFixed(1)}km';
      body = 'Bus is $dist away from ${stop.name}';
    }

    await _notificationService.showGeofenceNotification(
      title: title,
      body: body,
      tripId: tripId,
      additionalData: {
        'stop_id': stop.id,
        'stop_name': stop.name,
        'alert_type': alertType.name,
        'distance_meters': distance.toString(),
        'eta_minutes': etaMinutes.toString(),
        'student_ids': studentIds.join(','),
      },
    );

    // Mark as sent
    await _db.markAlertSent(alertId);

    // TODO: Send to backend for push notification delivery
    // This would trigger FCM notifications for other guardians
    await _sendToBackend(
      tripId: tripId,
      stopId: stop.id,
      alertType: alertType,
      distance: distance,
      etaMinutes: etaMinutes,
      studentIds: studentIds,
    );
  }

  /// Estimate ETA based on distance (when speed not available)
  int _estimateEtaFromDistance(double distanceMeters) {
    // Assume average speed of 20 km/h in urban areas
    const avgSpeedKmh = 20.0;
    return (distanceMeters / 1000 / avgSpeedKmh * 60).round();
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters

    final lat1 = _degreesToRadians(point1.latitude);
    final lat2 = _degreesToRadians(point2.latitude);
    final deltaLat = _degreesToRadians(point2.latitude - point1.latitude);
    final deltaLon = _degreesToRadians(point2.longitude - point1.longitude);

    final a = 
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) *
        sin(deltaLon / 2) * sin(deltaLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Send alert to backend for FCM delivery
  Future<void> _sendToBackend({
    required String tripId,
    required String stopId,
    required GeofenceAlertType alertType,
    required double distance,
    required int etaMinutes,
    required List<String> studentIds,
  }) async {
    // TODO: Implement API call to send geofence event to backend
    // Backend will then send FCM notifications to relevant guardians
    
    // Example payload:
    // {
    //   "trip_id": "...",
    //   "stop_id": "...",
    //   "alert_type": "approaching",
    //   "distance_meters": 1500,
    //   "eta_minutes": 5,
    //   "student_ids": ["..."],
    //   "timestamp": "..."
    // }

    if (kDebugMode) {
      print('📤 Sending geofence event to backend...');
    }
  }

  /// Get recent geofence alerts for current trip
  Future<List<GeofenceAlert>> getRecentAlerts() async {
    if (_currentTrip == null) return [];
    return _db.getGeofenceAlerts(_currentTrip!.id, limit: 20);
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get current trip being monitored
  api.Trip? get currentTrip => _currentTrip;

  /// Clear old alerts from database
  Future<void> clearOldAlerts() async {
    await _db.clearOldAlerts(daysToKeep: 7);
  }
}


