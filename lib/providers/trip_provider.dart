import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api.dart' as api;
import '../services/mqtt_service.dart';

/// Trip States
enum TripState {
  upcoming,
  ongoing,
  completed,
  cancelled,
}

/// Trip Provider - Manages trips with role-based access and MQTT
class TripProvider extends ChangeNotifier {
  final api.TripService _tripService = api.TripService();
  final MqttService _mqttService = MqttService();

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Trips data
  List<api.Trip> _trips = [];
  List<api.Trip> get trips => _trips;

  api.Trip? _activeTrip;
  api.Trip? get activeTrip => _activeTrip;

  // Role-based filtered trips
  List<api.Trip> get driverTrips => _trips.where((t) => t.status != 'cancelled').toList();
  
  List<api.Trip> get guardianTrips => _trips.where((t) => 
    t.students.any((s) => s.status != 'absent')
  ).toList();

  /// Initialize and connect to MQTT for real-time updates
  Future<void> initialize() async {
    await _mqttService.connect();
    
    // Listen to connection status
    _mqttService.connectionStatus.listen((connected) {
      if (connected) {
        _subscribeToTripTopics();
      }
    });
  }

  /// Subscribe to trip-related MQTT topics
  void _subscribeToTripTopics() {
    // Subscribe to trip events
    _mqttService.subscribe('trips/+/events', (topic, message) {
      _handleTripEvent(topic, message);
    });
  }

  void _handleTripEvent(String topic, String message) {
    try {
      final data = jsonDecode(message);
      final eventType = data['event'];
      final tripId = data['tripId'];

      switch (eventType) {
        case 'trip_started':
          _updateTripStatus(tripId, 'active');
          break;
        case 'trip_ended':
          _updateTripStatus(tripId, 'completed');
          break;
        case 'child_added':
        case 'child_removed':
          // Refresh trip data
          fetchActiveTrip();
          break;
      }
    } catch (e) {
      print('Failed to handle trip event: $e');
    }
  }

  void _updateTripStatus(String tripId, String status) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      // Update trip status
      notifyListeners();
    }
  }

  /// Fetch all trips (driver view)
  Future<void> fetchTrips({int page = 1, int limit = 20}) async {
    _setLoading(true);
    _clearError();

    try {
      _trips = await _tripService.getTrips(page: page, limit: limit);
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch trips');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch active trip
  Future<void> fetchActiveTrip() async {
    _setLoading(true);
    try {
      _activeTrip = await _tripService.getActiveTrip();
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch active trip');
    } finally {
      _setLoading(false);
    }
  }

  /// Start a trip (driver only)
  Future<api.Trip?> startTrip({
    required String routeId,
    required String vehicleId,
    List<String>? studentIds,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.startTrip(
        routeId: routeId,
        vehicleId: vehicleId,
        studentIds: studentIds,
      );
      
      _activeTrip = trip;
      _trips.insert(0, trip);
      
      // Publish MQTT event
      await _mqttService.publishJson(
        'trips/${trip.id}/events',
        {
          'event': 'trip_started',
          'tripId': trip.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      notifyListeners();
      return trip;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to start trip');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// End a trip (driver only)
  Future<bool> endTrip(String tripId) async {
    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.endTrip(tripId);
      
      // Update local state
      _activeTrip = null;
      final index = _trips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        _trips[index] = trip;
      }
      
      // Publish MQTT event
      await _mqttService.publishJson(
        'trips/$tripId/events',
        {
          'event': 'trip_ended',
          'tripId': tripId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to end trip');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update student pickup status
  Future<bool> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status,
    String? notes,
  }) async {
    try {
      await _tripService.updateStudentStatus(
        tripId: tripId,
        studentId: studentId,
        status: status,
        notes: notes,
      );
      
      // Update local state
      final tripIndex = _trips.indexWhere((t) => t.id == tripId);
      if (tripIndex != -1) {
        final studentIndex = _trips[tripIndex].students.indexWhere((s) => s.id == studentId);
        if (studentIndex != -1) {
          // Update student status locally
          notifyListeners();
        }
      }
      
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update status');
      return false;
    }
  }

  /// Fetch trips for a specific child (guardian view)
  Future<void> fetchTripsForChild(String childId) async {
    _setLoading(true);
    _clearError();

    try {
      // This would filter trips by child ID
      // For now, fetch all and filter locally
      final allTrips = await _tripService.getTrips();
      _trips = allTrips.where((t) => 
        t.students.any((s) => s.id == childId)
      ).toList();
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch trips');
    } finally {
      _setLoading(false);
    }
  }

  /// Get trip by ID
  api.Trip? getTripById(String tripId) {
    return _trips.firstWhere((t) => t.id == tripId, orElse: () => null as api.Trip);
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }
}
