import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart' as api;
import '../mqtt_client.dart';
import '../services/trip_history_service.dart';
import '../utils/notification_helper.dart';

/// Trip States
enum TripState { upcoming, ongoing, completed, cancelled }

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
  List<api.Trip> get driverTrips =>
      _trips.where((t) => t.status != 'cancelled').toList();

  List<api.Trip> get guardianTrips =>
      _trips.where((t) => t.students.any((s) => s.status != 'absent')).toList();

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
  /// For guardians, pass their phone number to get their active trip
  Future<void> fetchActiveTrip({String? guardianPhone}) async {
    // Use microtask to avoid calling notifyListeners during build
    await Future.microtask(() => _setLoading(true));
    try {
      _activeTrip = await _tripService.getActiveTrip(
        guardianPhone: guardianPhone,
      );
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
    String? route,
    String? tripName,
    String? driverName,
    String? numberPlate,
    String? driverPhoneNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.startTrip(
        routeId: routeId,
        vehicleId: vehicleId,
        studentIds: studentIds,
        route: route,
        tripName: tripName,
        driverName: driverName,
        numberPlate: numberPlate,
        driverPhoneNumber: driverPhoneNumber,
      );

      _activeTrip = trip;
      _trips.insert(0, trip);

      // Publish MQTT event (don't fail if MQTT is not connected)
      try {
        await _mqttService.publishJson('trips/${trip.id}/events', {
          'event': 'trip_started',
          'tripId': trip.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ MQTT publish failed: $e');
        }
        // Continue - don't fail the trip because of MQTT
      }

      // Show notification (don't fail if notification fails)
      try {
        await NotificationHelper.showTripStarted(
          tripId: trip.id,
          routeName: trip.routeName,
          vehicleNumber: trip.vehicleNumber,
          studentCount: trip.students.length,
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Notification failed: $e');
        }
        // Continue - don't fail the trip because of notification
      }

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
  Future<bool> endTrip(String tripId, {String? driverId, String? driverName}) async {
    _setLoading(true);
    _clearError();

    api.Trip? endedTrip;
    bool apiSuccess = false;
    
    // Save original student data before API call - the API might return empty students
    final originalStudents = _activeTrip?.students ?? [];
    final originalRouteName = _activeTrip?.routeName ?? 'Trip';
    final originalVehicleId = _activeTrip?.vehicleId ?? '';
    final originalStartTime = _activeTrip?.startTime ?? DateTime.now();

    try {
      endedTrip = await _tripService.endTrip(tripId);
      apiSuccess = true;

      // If API returned empty students but we had original data, preserve it
      if ((endedTrip.students.isEmpty) && originalStudents.isNotEmpty) {
        if (kDebugMode) {
          print('🔄 API returned empty students, preserving original student data (${originalStudents.length} students)');
        }
        endedTrip = api.Trip(
          id: endedTrip.id,
          routeName: endedTrip.routeName.isNotEmpty ? endedTrip.routeName : originalRouteName,
          routeId: endedTrip.routeId,
          startTime: endedTrip.startTime,
          endTime: endedTrip.endTime ?? DateTime.now(),
          status: endedTrip.status,
          vehicleId: endedTrip.vehicleId.isNotEmpty ? endedTrip.vehicleId : originalVehicleId,
          vehicleNumber: endedTrip.vehicleNumber,
          students: originalStudents,
          stops: endedTrip.stops,
          distance: endedTrip.distance,
          fare: endedTrip.fare,
          notes: endedTrip.notes,
        );
      }

      // Update local state - always clear active trip
      _activeTrip = null;
      final index = _trips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        _trips[index] = endedTrip;
      }
    } on api.ApiException catch (e) {
      // Check if it's just an empty response error - if so, still consider it success
      if (e.message.toLowerCase().contains('empty') || 
          e.message.toLowerCase().contains('null')) {
        print('⚠️ Server returned empty response, but trip was likely ended');
        _activeTrip = null;
        apiSuccess = true;
        // Create a completed trip preserving original student data
        endedTrip = api.Trip(
          id: tripId,
          routeName: originalRouteName,
          routeId: '',
          startTime: originalStartTime,
          endTime: DateTime.now(),
          status: 'completed',
          vehicleId: originalVehicleId,
          students: originalStudents,
          stops: [],
        );
      } else {
        _setError(e.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to end trip');
      _setLoading(false);
      return false;
    }

    // Update trip history with completed status (runs for both success and empty response cases)
    if (driverId != null && endedTrip != null) {
      try {
        final historyService = TripHistoryService();
        final history = await historyService.getTripHistory(driverId);
        final historyIndex = history.indexWhere((h) => h.trip.id == tripId);
        
        if (historyIndex != -1) {
          // Update the existing history entry with completed trip
          final updatedHistory = TripHistory(
            trip: endedTrip,
            driverId: history[historyIndex].driverId,
            driverName: history[historyIndex].driverName,
            attendantName: history[historyIndex].attendantName,
            loggedAt: history[historyIndex].loggedAt,
          );
          
          history[historyIndex] = updatedHistory;
          
          // Save updated history
          final prefs = await SharedPreferences.getInstance();
          final tripsJson = history.map((t) => t.toJson()).toList();
          await prefs.setString('driver_trip_history_$driverId', jsonEncode(tripsJson));
          
          if (kDebugMode) {
            print('✅ Trip history updated with completed status: $tripId');
          }
        } else {
          // If not in history, save it now
          await historyService.saveTripToHistory(
            trip: endedTrip,
            driverId: driverId,
            driverName: driverName ?? 'Driver',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to update trip history: $e');
        }
      }
    }

    // Publish MQTT event (don't fail if MQTT errors)
    try {
      await _mqttService.publishJson('trips/$tripId/events', {
        'event': 'trip_ended',
        'tripId': tripId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ MQTT publish failed: $e');
    }

    // Show notification (wrap in try-catch in case of minimal trip object)
    try {
      final pickedCount = endedTrip?.pickedCount ?? 0;
      final totalStudents = endedTrip?.students.length ?? 0;
      await NotificationHelper.showTripCompleted(
        tripId: tripId,
        routeName: endedTrip?.routeName ?? 'Trip',
        totalStudents: totalStudents,
        pickedCount: pickedCount,
        absentCount: endedTrip?.absentCount ?? 0,
      );
    } catch (e) {
      print('⚠️ Notification failed: $e');
    }

    notifyListeners();
    _setLoading(false);
    return apiSuccess;
  }

  /// Update student pickup status
  Future<bool> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status,
    String? notes,
  }) async {
    try {
      // Get student info before updating
      String? studentName;
      final tripIndex = _trips.indexWhere((t) => t.id == tripId);
      if (tripIndex != -1) {
        final studentIndex = _trips[tripIndex].students.indexWhere(
          (s) => s.id == studentId,
        );
        if (studentIndex != -1) {
          studentName = _trips[tripIndex].students[studentIndex].name;
        }
      }

      await _tripService.updateStudentStatus(
        tripId: tripId,
        studentId: studentId,
        status: status,
        notes: notes,
      );

      // Update local state
      if (tripIndex != -1) {
        final studentIndex = _trips[tripIndex].students.indexWhere(
          (s) => s.id == studentId,
        );
        if (studentIndex != -1) {
          // Update student status locally
          notifyListeners();
        }
      }

      // Show notification based on status
      if (studentName != null) {
        if (status == 'picked') {
          await NotificationHelper.showChildPickedUp(
            studentName: studentName,
            tripId: tripId,
          );
        } else if (status == 'absent') {
          await NotificationHelper.showChildAbsent(
            studentName: studentName,
            tripId: tripId,
            reason: notes,
          );
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
      _trips = allTrips
          .where((t) => t.students.any((s) => s.id == childId))
          .toList();
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
    try {
      return _trips.firstWhere((t) => t.id == tripId);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // MASTER TRIPS - New API Integration
  // ============================================================================

  // Master trips data
  List<api.MasterTrip> _masterTrips = [];
  List<api.MasterTrip> get masterTrips => _masterTrips;

  api.MasterTrip? _selectedMasterTrip;
  api.MasterTrip? get selectedMasterTrip => _selectedMasterTrip;

  List<api.TripStudent> _tripStudents = [];
  List<api.TripStudent> get tripStudents => _tripStudents;

  List<api.TripGuardian> _tripGuardians = [];
  List<api.TripGuardian> get tripGuardians => _tripGuardians;

  /// Fetch all master trips
  Future<void> fetchMasterTrips() async {
    _setLoading(true);
    _clearError();

    try {
      _masterTrips = await _tripService.getAllMasterTrips();
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch trips');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch students for a specific master trip (for guardians)
  /// Maps students by guardian phone number
  Future<void> fetchMasterTripStudents(int masterTripId) async {
    _setLoading(true);
    _clearError();

    try {
      _tripStudents = await _tripService.getMasterTripStudents(masterTripId);
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch trip students');
    } finally {
      _setLoading(false);
    }
  }

  /// Get students for a specific guardian by phone number
  List<api.TripStudent> getGuardianStudents(String guardianPhone) {
    return _tripStudents
        .where((s) => s.guardianPhoneNumber == guardianPhone)
        .toList();
  }

  /// Fetch guardians for a master trip (for drivers)
  Future<void> fetchTripGuardians(int masterTripId) async {
    _setLoading(true);
    _clearError();

    try {
      _tripGuardians = await _tripService.getStudentsGuardiansInMasterTrips(
        masterTripId,
      );
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch guardians');
    } finally {
      _setLoading(false);
    }
  }

  /// Select a master trip
  void selectMasterTrip(api.MasterTrip trip) {
    _selectedMasterTrip = trip;
    notifyListeners();
  }

  /// Clear master trip data
  void clearMasterTripData() {
    _selectedMasterTrip = null;
    _tripStudents = [];
    _tripGuardians = [];
    notifyListeners();
  }

  /// Create a new master trip
  Future<api.MasterTrip?> createMasterTrip({
    required String tripName,
    required String tripTime,
    required String tripDirection,
    required String route,
    required String numberPlate,
    required String attendantName,
    required String driverName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.createMasterTrip(
        tripName: tripName,
        tripTime: tripTime,
        tripDirection: tripDirection,
        route: route,
        numberPlate: numberPlate,
        attendantName: attendantName,
        driverName: driverName,
      );

      _masterTrips.insert(0, trip);
      notifyListeners();
      return trip;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to create trip');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Edit an existing master trip
  Future<api.MasterTrip?> editMasterTrip({
    required int tripId,
    String? tripName,
    String? tripTime,
    String? tripDirection,
    String? route,
    String? numberPlate,
    String? attendantName,
    String? driverName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.editMasterTrip(
        tripId: tripId,
        tripName: tripName,
        tripTime: tripTime,
        tripDirection: tripDirection,
        route: route,
        numberPlate: numberPlate,
        attendantName: attendantName,
        driverName: driverName,
      );

      // Update the trip in the list
      final index = _masterTrips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        _masterTrips[index] = trip;
      }

      // Update selected trip if it's the one being edited
      if (_selectedMasterTrip?.id == tripId) {
        _selectedMasterTrip = trip;
      }

      notifyListeners();
      return trip;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to update trip');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a master trip
  Future<bool> deleteMasterTrip(int tripId) async {
    _setLoading(true);
    _clearError();

    try {
      await _tripService.deleteMasterTrip(tripId);

      _masterTrips.removeWhere((t) => t.id == tripId);

      if (_selectedMasterTrip?.id == tripId) {
        _selectedMasterTrip = null;
      }

      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to delete trip');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Add a student to a master trip
  Future<api.TripStudent?> addStudentToMasterTrip({
    required int masterTripId,
    required String fullname,
    required String studentRegNumber,
    required int studentId,
    required String guardianPhoneNumber,
    required String schoolname,
    required String classname,
    required String route,
    required double latitude,
    required double longitude,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final student = await _tripService.addStudentToMasterTrip(
        masterTripId: masterTripId,
        fullname: fullname,
        studentRegNumber: studentRegNumber,
        studentId: studentId,
        guardianPhoneNumber: guardianPhoneNumber,
        schoolname: schoolname,
        classname: classname,
        route: route,
        latitude: latitude,
        longitude: longitude,
      );

      if (_selectedMasterTrip?.id == masterTripId) {
        _tripStudents.add(student);
      }

      notifyListeners();
      return student;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to add student to trip');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a student from a master trip
  Future<bool> deleteStudentFromMasterTrip({
    required int studentTripId,
    required int masterTripId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _tripService.deleteStudentFromMasterTrip(
        studentTripId: studentTripId,
        masterTripId: masterTripId,
      );

      _tripStudents.removeWhere((s) => s.id == studentTripId);
      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to remove student from trip');
      return false;
    } finally {
      _setLoading(false);
    }
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
