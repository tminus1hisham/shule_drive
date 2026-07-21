import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart' as api;
import '../mqtt_client.dart';
import '../services/guardian_trip_notification_service.dart';
import '../services/trip_history_service.dart';
import '../utils/notification_helper.dart';
import '../utils/student_trip_logic.dart';

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

  // Trip unique ID from start trip API - needed for pick/drop operations
  String? _activeTripUniqueId;
  String? get activeTripUniqueId => _activeTripUniqueId;

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
      debugPrint('Failed to handle trip event: $e');
    }
  }

  void _updateTripStatus(String tripId, String status) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: status);
      if (_activeTrip?.id == tripId) {
        _activeTrip = _activeTrip!.copyWith(status: status);
      }
      notifyListeners();
    }
  }

  api.Trip? _findTrip(String tripId) {
    if (_activeTrip?.id == tripId) return _activeTrip;
    try {
      return _trips.firstWhere((t) => t.id == tripId);
    } catch (_) {
      return null;
    }
  }

  void _replaceTrip(api.Trip trip) {
    if (_activeTrip?.id == trip.id) {
      _activeTrip = trip;
    }

    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index == -1) {
      _trips.insert(0, trip);
    } else {
      _trips[index] = trip;
    }
  }

  bool _guardianPhoneMatches(String? studentPhone, String guardianPhone) {
    final studentDigits = normalizeGuardianPhone(studentPhone);
    final guardianDigits = normalizeGuardianPhone(guardianPhone);

    return studentDigits.isNotEmpty && studentDigits == guardianDigits;
  }

  api.Trip _filterTripForGuardian(api.Trip trip, String guardianPhone) {
    final students = trip.students
        .where((student) => _guardianPhoneMatches(student.parentPhone, guardianPhone))
        .toList();

    return trip.copyWith(students: students);
  }

  api.Trip _withStudentStatus({
    required api.Trip trip,
    required String studentId,
    required String status,
    String? notes,
    double? latitude,
    double? longitude,
  }) {
    final normalizedStatus = api.StudentPickup.normalizeStatus(status);
    final now = DateTime.now();
    final students = trip.students.map((student) {
      if (student.id != studentId) return student;

      final shouldSavePickupLocation =
          normalizedStatus == 'picked' &&
          latitude != null &&
          longitude != null &&
          !student.hasSavedHomeDestination;

      return student.copyWith(
        status: normalizedStatus,
        pickupTime: normalizedStatus == 'picked'
            ? now
            : student.pickupTime,
        dropoffTime: normalizedStatus == 'dropped'
            ? now
            : student.dropoffTime,
        notes: notes ?? student.notes,
        latitude: shouldSavePickupLocation ? latitude : student.latitude,
        longitude: shouldSavePickupLocation ? longitude : student.longitude,
        pickedLatitude: shouldSavePickupLocation
            ? latitude
            : student.pickedLatitude,
        pickedLongitude: shouldSavePickupLocation
            ? longitude
            : student.pickedLongitude,
        droppedLatitude: normalizedStatus == 'dropped' && latitude != null
            ? latitude
            : student.droppedLatitude,
        droppedLongitude: normalizedStatus == 'dropped' && longitude != null
            ? longitude
            : student.droppedLongitude,
      );
    }).toList();

    return trip.copyWith(students: students);
  }

  api.Trip _withBulkStudentStatus({
    required api.Trip trip,
    required String fromStatus,
    required String toStatus,
  }) {
    final normalizedFrom = api.StudentPickup.normalizeStatus(fromStatus);
    final normalizedTo = api.StudentPickup.normalizeStatus(toStatus);
    final now = DateTime.now();
    final students = trip.students.map((student) {
      if (api.StudentPickup.normalizeStatus(student.status) != normalizedFrom) {
        return student;
      }

      return student.copyWith(
        status: normalizedTo,
        pickupTime: normalizedTo == 'picked' ? now : student.pickupTime,
        dropoffTime: normalizedTo == 'dropped' ? now : student.dropoffTime,
      );
    }).toList();

    return trip.copyWith(students: students);
  }

  /// Rank used to decide which student status is further along when merging
  /// fetched trip data with locally recorded statuses.
  static int _statusRank(String status) {
    switch (api.StudentPickup.normalizeStatus(status)) {
      case 'absent':
        return 1;
      case 'picked':
        return 2;
      case 'dropped':
        return 3;
      default:
        return 0; // pending
    }
  }

  /// The driver has no working server read for the active trip (the endpoint
  /// requires guardianPhone) and there is no per-student pick API, so fetched
  /// or history-restored data can carry statuses older than what this
  /// provider already recorded. Keep the further-along status per student
  /// instead of downgrading.
  @visibleForTesting
  static api.Trip mergeWithLocalStatuses(api.Trip fetched, api.Trip local) {
    if (fetched.id != local.id) return fetched;

    if (fetched.students.isEmpty && local.students.isNotEmpty) {
      return fetched.copyWith(students: local.students);
    }

    final localById = {for (final s in local.students) s.id: s};
    final students = fetched.students.map((student) {
      final localStudent = localById[student.id];
      if (localStudent == null) return student;
      return _statusRank(localStudent.status) > _statusRank(student.status)
          ? localStudent
          : student;
    }).toList();

    return fetched.copyWith(students: students);
  }

  /// Write an updated trip back to the active-trip buffer and local trip
  /// history so fetch fallbacks don't resurrect pre-update statuses.
  void _persistTripState(api.Trip trip) {
    if (_activeTrip?.id == trip.id) {
      unawaited(_tripService.cacheActiveTrip(trip));
    }
    unawaited(TripHistoryService().updateTripInHistory(trip));
  }

  /// Notify each guardian whose student's status changed between [before] and
  /// [after], over MQTT, so the guardian app raises a live notification.
  void _broadcastStatusChanges({
    required api.Trip before,
    required api.Trip after,
  }) {
    final beforeById = {for (final s in before.students) s.id: s.status};
    final vehicleNumber = after.vehicleNumber ?? after.vehicleId;

    for (final student in after.students) {
      final prev = beforeById[student.id];
      final now = api.StudentPickup.normalizeStatus(student.status);
      final wasSame =
          prev != null && api.StudentPickup.normalizeStatus(prev) == now;
      if (wasSame) continue;
      if (now == 'picked' || now == 'dropped' || now == 'absent') {
        _publishGuardianStudentStatus(
          student: student,
          status: now,
          tripId: after.id,
          vehicleNumber: vehicleNumber,
        );
      }
    }
  }

  void _publishGuardianStudentStatus({
    required api.StudentPickup student,
    required String status,
    required String tripId,
    String? vehicleNumber,
  }) {
    final phone = student.parentPhone;
    if (phone == null || phone.trim().isEmpty) return;
    if (!_mqttService.isConnected) return;

    try {
      _mqttService.publishJson(
        GuardianTripNotificationService.topicForPhone(phone),
        GuardianTripNotificationService.buildPayload(
          studentId: student.id,
          studentName: student.name,
          status: status,
          tripId: tripId,
          vehicleNumber: vehicleNumber,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to publish guardian status: $e');
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
  /// For guardians, pass their phone number to get their active trip.
  /// For drivers, pass [driverId] so a running trip can be restored from
  /// local trip history when the API/buffer have no record of it
  /// (e.g. after the app was killed and reopened).
  Future<void> fetchActiveTrip({String? guardianPhone, String? driverId}) async {
    // Use microtask to avoid calling notifyListeners during build
    await Future.microtask(() => _setLoading(true));
    try {
      final previousTrip = _activeTrip;
      var fetched = await _tripService.getActiveTrip(
        guardianPhone: guardianPhone,
      );
      if (fetched != null &&
          guardianPhone != null &&
          guardianPhone.isNotEmpty) {
        fetched = _filterTripForGuardian(fetched, guardianPhone);
      }
      if (fetched == null && driverId != null && driverId.isNotEmpty) {
        fetched = await _restoreActiveTripFromHistory(driverId);
        if (fetched != null) {
          _activeTripUniqueId = fetched.id;
        }
      }
      if (fetched != null && previousTrip != null) {
        fetched = mergeWithLocalStatuses(fetched, previousTrip);
      }
      _activeTrip = fetched;
      notifyListeners();

      // Drivers have no active-trip endpoint, but the master trip roster is
      // readable without a guardian phone and carries server pick state.
      if (fetched != null && driverId != null && driverId.isNotEmpty) {
        await syncActiveTripStudentsFromServer();
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch active trip');
    } finally {
      _setLoading(false);
    }
  }

  /// Reconcile the active trip's students with the server.
  ///
  /// `GET /api/trips/get/master/trip/students` needs only a masterTripId, so
  /// unlike the active-trip endpoint a driver can call it. Its rows carry
  /// `isStudentPicked` / `isStudentDropped`, which is the closest thing to a
  /// server-side read of pick state the driver has.
  ///
  /// Statuses are merged further-along-wins, so a server row that has not
  /// caught up yet can never downgrade a pick this device just recorded.
  Future<void> syncActiveTripStudentsFromServer() async {
    final trip = _activeTrip;
    final masterTripId = trip?.masterTripId;
    if (trip == null || masterTripId == null) return;

    try {
      final rows = await _tripService.getMasterTripStudents(
        masterTripId,
        forceRefresh: true,
      );
      if (rows.isEmpty) return;

      final serverTrip = trip.copyWith(
        students: rows
            .map((row) => api.StudentPickup.fromJson(row.toJson()))
            .toList(),
      );

      final merged = mergeWithLocalStatuses(serverTrip, trip);
      if (_activeTrip?.id != trip.id) return; // trip changed while awaiting

      _activeTrip = merged;
      _persistTripState(merged);
      notifyListeners();
    } catch (e) {
      // Best-effort reconciliation - local state stays authoritative on failure
      debugPrint('⚠️ Failed to sync trip students from server: $e');
    }
  }

  /// How long a locally recorded trip stays restorable as "active".
  /// Guards against resurrecting stale trips that were never ended cleanly.
  static const Duration _maxRestorableTripAge = Duration(hours: 12);

  /// Restore the driver's running trip from local trip history.
  /// History entries are saved as 'active' when a trip starts and updated to
  /// 'completed' when it ends, so the newest active entry is the running trip.
  Future<api.Trip?> _restoreActiveTripFromHistory(String driverId) async {
    try {
      final history = await TripHistoryService().getTripHistory(driverId);
      for (final entry in history) {
        final trip = entry.trip;
        if (!trip.isActive) continue;
        if (DateTime.now().difference(trip.startTime) >
            _maxRestorableTripAge) {
          continue;
        }
        debugPrint('🔄 Restored active trip from local history: ${trip.id}');
        return trip;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore active trip from history: $e');
    }
    return null;
  }

  /// Start a trip (driver only)
  Future<api.Trip?> startTrip({
    required String routeId,
    required String vehicleId,
    List<String>? studentIds,
    int? masterTripId,
    String? route,
    String? tripName,
    String? driverName,
    String? numberPlate,
    String? driverPhoneNumber,
    String? attendantName,
    String? attendantPhoneNumber,
    String? attendantProfileImage,
  }) async {
    // Hard guard: never allow two trips at once
    if (_activeTrip != null && _activeTrip!.isActive) {
      _setError(
        'A trip is already in progress. End the current trip before starting a new one.',
      );
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final trip = await _tripService.startTrip(
        routeId: routeId,
        vehicleId: vehicleId,
        studentIds: studentIds,
        masterTripId: masterTripId,
        route: route,
        tripName: tripName,
        driverName: driverName,
        numberPlate: numberPlate,
        driverPhoneNumber: driverPhoneNumber,
        attendantName: attendantName,
        attendantPhoneNumber: attendantPhoneNumber,
        attendantProfileImage: attendantProfileImage,
      );

      _activeTrip = trip;
      _activeTripUniqueId =
          trip.id; // Store the unique ID for pick/drop operations
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

      // Show local notification (don't fail if notification fails)
      try {
        await NotificationHelper.showTripStarted(
          tripId: trip.id,
          routeName: trip.routeName,
          vehicleNumber: trip.vehicleNumber,
          studentCount: trip.students.length,
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Local notification failed: $e');
        }
        // Continue - don't fail the trip because of notification
      }

      // Notify guardians via API (don't fail if notification fails)
      try {
        final studentIds = trip.students.map((s) => s.id).toList();
        await _tripService.notifyGuardiansTripStarted(
          tripId: trip.id,
          studentIds: studentIds,
          routeName: trip.routeName,
          vehicleNumber: trip.vehicleNumber,
        );
        if (kDebugMode) {
          print('✅ Guardians notified of trip start');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Guardian notification failed: $e');
        }
        // Continue - don't fail the trip because of guardian notification
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

  /// Update active trip with merged/preserved data
  void updateActiveTrip(api.Trip trip) {
    _activeTrip = trip;
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index != -1) {
      _trips[index] = trip;
    }
    notifyListeners();
    if (kDebugMode) {
      print('🔄 Active trip updated with preserved student data');
    }
  }

  /// Seed the active trip with the full student roster (and missing trip
  /// details) preloaded for the driver before the trip screen opened.
  ///
  /// The start-trip API returns no students, so this provider's active trip
  /// can be empty even though the active-trip screen holds the full roster.
  /// Without seeding, per-student pick/drop updates match nothing here and
  /// [endTrip] persists an empty student list to history (trip details then
  /// show "0 students / Unknown Vehicle"). Merges by id, keeping whichever
  /// status is further along so already-recorded picks are never downgraded.
  void hydrateActiveTrip({
    required List<api.StudentPickup> roster,
    String? vehicleNumber,
    String? routeName,
  }) {
    final trip = _activeTrip;
    if (trip == null) return;

    var updatedTrip = trip;

    if (roster.isNotEmpty) {
      final existingById = {for (final s in trip.students) s.id: s};
      final seenIds = <String>{};
      final merged = <api.StudentPickup>[];

      for (final rosterStudent in roster) {
        seenIds.add(rosterStudent.id);
        final existing = existingById[rosterStudent.id];
        if (existing == null) {
          merged.add(rosterStudent);
          continue;
        }
        // Keep the further-along status, but take the roster's richer profile.
        final keepExistingStatus =
            _statusRank(existing.status) >= _statusRank(rosterStudent.status);
        merged.add(
          rosterStudent.copyWith(
            status: keepExistingStatus ? existing.status : rosterStudent.status,
            pickupTime: existing.pickupTime ?? rosterStudent.pickupTime,
            dropoffTime: existing.dropoffTime ?? rosterStudent.dropoffTime,
          ),
        );
      }

      // Preserve any provider-only students not present in the roster.
      for (final existing in trip.students) {
        if (!seenIds.contains(existing.id)) merged.add(existing);
      }

      updatedTrip = updatedTrip.copyWith(students: merged);
    }

    if ((updatedTrip.vehicleNumber == null ||
            updatedTrip.vehicleNumber!.isEmpty) &&
        vehicleNumber != null &&
        vehicleNumber.isNotEmpty) {
      updatedTrip = updatedTrip.copyWith(vehicleNumber: vehicleNumber);
    }

    if (updatedTrip.routeName.isEmpty &&
        routeName != null &&
        routeName.isNotEmpty) {
      updatedTrip = updatedTrip.copyWith(routeName: routeName);
    }

    if (identical(updatedTrip, trip)) return;

    _replaceTrip(updatedTrip);
    notifyListeners();
    _persistTripState(updatedTrip);
  }

  /// End a trip (driver only)
  Future<bool> endTrip(
    String tripId, {
    String? driverId,
    String? driverName,
  }) async {
    _setLoading(true);
    _clearError();

    api.Trip? endedTrip;
    bool apiSuccess = false;

    // Save original student data before API call - the API might return empty students
    final originalStudents = _activeTrip?.students ?? [];
    final originalRouteName = _activeTrip?.routeName ?? 'Trip';
    final originalVehicleId = _activeTrip?.vehicleId ?? '';
    final originalVehicleNumber = _activeTrip?.vehicleNumber;
    final originalStartTime = _activeTrip?.startTime ?? DateTime.now();

    try {
      endedTrip = await _tripService.endTrip(tripId);
      apiSuccess = true;

      // If API returned empty students but we had original data, preserve it
      // Also ensure status is 'completed' since we just ended the trip
      if ((endedTrip.students.isEmpty) && originalStudents.isNotEmpty) {
        if (kDebugMode) {
          print(
            '🔄 API returned empty students, preserving original student data (${originalStudents.length} students)',
          );
        }
        endedTrip = api.Trip(
          id: endedTrip.id,
          routeName: endedTrip.routeName.isNotEmpty
              ? endedTrip.routeName
              : originalRouteName,
          routeId: endedTrip.routeId,
          startTime: endedTrip.startTime,
          endTime: endedTrip.endTime ?? DateTime.now(),
          status: 'completed',
          vehicleId: endedTrip.vehicleId.isNotEmpty
              ? endedTrip.vehicleId
              : originalVehicleId,
          vehicleNumber: endedTrip.vehicleNumber ?? originalVehicleNumber,
          students: originalStudents,
          stops: endedTrip.stops,
          distance: endedTrip.distance,
          fare: endedTrip.fare,
          notes: endedTrip.notes,
        );
      } else {
        // Even if API returned data, ensure status is completed
        // The API might return the old status
        if (endedTrip.status != 'completed') {
          endedTrip = api.Trip(
            id: endedTrip.id,
            routeName: endedTrip.routeName,
            routeId: endedTrip.routeId,
            startTime: endedTrip.startTime,
            endTime: endedTrip.endTime ?? DateTime.now(),
            status: 'completed',
            vehicleId: endedTrip.vehicleId,
            vehicleNumber: endedTrip.vehicleNumber ?? originalVehicleNumber,
            students: endedTrip.students,
            stops: endedTrip.stops,
            distance: endedTrip.distance,
            fare: endedTrip.fare,
            notes: endedTrip.notes,
          );
        }
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
        debugPrint(
          '⚠️ Server returned empty response, but trip was likely ended',
        );
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
          vehicleNumber: originalVehicleNumber,
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
    // endedTrip is guaranteed to be non-null here (set in both success and catch blocks)
    if (driverId != null) {
      try {
        final historyService = TripHistoryService();
        final history = await historyService.getTripHistory(driverId);

        // Find the most recent ACTIVE entry with this trip ID
        // This prevents overwriting older completed trips with the same master trip ID
        int historyIndex = -1;
        for (int i = 0; i < history.length; i++) {
          if (history[i].trip.id == tripId && !history[i].trip.isCompleted) {
            historyIndex = i;
            break;
          }
        }

        // If no active entry, try finding any entry with this ID (fallback)
        if (historyIndex == -1) {
          historyIndex = history.indexWhere((h) => h.trip.id == tripId);
        }

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
          await prefs.setString(
            'driver_trip_history_$driverId',
            jsonEncode(tripsJson),
          );

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
      debugPrint('⚠️ MQTT publish failed: $e');
    }

    // Show notification (wrap in try-catch in case of minimal trip object)
    try {
      final pickedCount = endedTrip.pickedCount;
      final totalStudents = endedTrip.students.length;
      await NotificationHelper.showTripCompleted(
        tripId: tripId,
        routeName: endedTrip.routeName,
        totalStudents: totalStudents,
        pickedCount: pickedCount,
        absentCount: endedTrip.absentCount,
      );
    } catch (e) {
      debugPrint('⚠️ Notification failed: $e');
    }

    notifyListeners();
    _setLoading(false);
    return apiSuccess;
  }

  /// Apply a student status change to local provider state (active trip, trips
  /// list, active-trip cache and history) and notify listeners + guardians,
  /// WITHOUT calling the pick/drop API.
  ///
  /// Use when the caller has already persisted the change through the API
  /// itself (e.g. the map tracking screen, which supplies its own richer
  /// student reg / guardian phone / number plate) but still needs every screen
  /// bound to this provider — the students-list screen in particular — to
  /// reflect it. No-op if this trip/student isn't tracked here.
  void reflectStudentStatusLocally({
    required String tripId,
    required String studentId,
    required String status,
    String? notes,
    double? latitude,
    double? longitude,
  }) {
    final existingTrip = _findTrip(tripId);
    if (existingTrip == null) return;

    final updatedTrip = _withStudentStatus(
      trip: existingTrip,
      studentId: studentId,
      status: api.StudentPickup.normalizeStatus(status),
      notes: notes,
      latitude: latitude,
      longitude: longitude,
    );
    _replaceTrip(updatedTrip);
    notifyListeners();
    _persistTripState(updatedTrip);
    _broadcastStatusChanges(before: existingTrip, after: updatedTrip);
  }

  /// Update student pickup status
  Future<bool> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final normalizedStatus = api.StudentPickup.normalizeStatus(status);
      // Get student info before updating
      String? studentName;
      final existingTrip = _findTrip(tripId);
      api.StudentPickup? existingStudent;
      if (existingTrip != null) {
        for (final student in existingTrip.students) {
          if (student.id == studentId) {
            existingStudent = student;
            break;
          }
        }
      }
      studentName = existingStudent?.name;

      await _tripService.updateStudentStatus(
        tripId: tripId,
        studentId: studentId,
        status: normalizedStatus,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
        // Required by the single-student pick/drop endpoint.
        studentReg: existingStudent?.studentRegNumber,
        guardianPhoneNumber: existingStudent?.parentPhone,
        numberPlate: existingTrip?.vehicleNumber ?? existingTrip?.vehicleId,
      );

      reflectStudentStatusLocally(
        tripId: tripId,
        studentId: studentId,
        status: normalizedStatus,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
      );

      // Show notification based on status
      if (studentName != null) {
        if (normalizedStatus == 'picked') {
          await NotificationHelper.showChildPickedUp(
            studentName: studentName,
            tripId: tripId,
          );
        } else if (normalizedStatus == 'absent') {
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

  /// Pick all students in a trip
  Future<bool> pickAllStudents(
    String tripId, {
    double latitude = 0,
    double longitude = 0,
  }) async {
    try {
      await _tripService.pickAllStudents(
        tripId,
        latitude: latitude,
        longitude: longitude,
      );

      // Update local state
      final trip = _findTrip(tripId);
      if (trip != null) {
        final updatedTrip = _withBulkStudentStatus(
          trip: trip,
          fromStatus: 'pending',
          toStatus: 'picked',
        );
        _replaceTrip(updatedTrip);
        notifyListeners();
        _persistTripState(updatedTrip);
        _broadcastStatusChanges(before: trip, after: updatedTrip);
      }

      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to pick all students');
      return false;
    }
  }

  /// Drop all students in a trip
  Future<bool> dropAllStudents(
    String tripId, {
    double latitude = 0,
    double longitude = 0,
  }) async {
    try {
      await _tripService.dropAllStudents(
        tripId,
        latitude: latitude,
        longitude: longitude,
      );

      // Update local state
      final trip = _findTrip(tripId);
      if (trip != null) {
        final updatedTrip = _withBulkStudentStatus(
          trip: trip,
          fromStatus: 'picked',
          toStatus: 'dropped',
        );
        _replaceTrip(updatedTrip);
        notifyListeners();
        _persistTripState(updatedTrip);
        _broadcastStatusChanges(before: trip, after: updatedTrip);
      }

      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to drop all students');
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

      // Add to local state unconditionally since UI fetches it immediately prior
      _tripStudents.add(student);

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
      api.TripStudent? assignedStudent;
      for (final student in _tripStudents) {
        if (student.id == studentTripId) {
          assignedStudent = student;
          break;
        }
      }
      final apiStudentId = assignedStudent?.studentId ?? studentTripId;

      await _tripService.deleteStudentFromMasterTrip(
        studentId: apiStudentId,
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

  /// Send ETA notification to guardians (2 minutes before arrival)
  Future<bool> sendEtaNotification({
    required String tripId,
    required String studentId,
    required String stopId,
    required String stopName,
    required int etaMinutes,
  }) async {
    try {
      await _tripService.notifyGuardiansEta(
        tripId: tripId,
        studentId: studentId,
        stopId: stopId,
        stopName: stopName,
        etaMinutes: etaMinutes,
      );
      return true;
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('⚠️ ETA notification API error: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ ETA notification error: $e');
      }
      return false;
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
