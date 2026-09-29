import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../models/master_trip.dart';
import '../../utils/buffer_manager.dart';
import 'bus_service.dart';

/// Trip Service - Handles trip-related API calls with fallback buffers
class TripService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get all trips with buffer fallback
  /// GET /trips
  Future<List<Trip>> getTrips({int page = 1, int limit = 20}) async {
    return _buffer.withBuffer<List<Trip>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getAllMasterTrips);

        final tripsData = ApiClient.unwrapList(response);

        final trips = tripsData.map((trip) => Trip.fromJson(trip)).toList();
        return trips;
      },
      bufferKey: BufferKeys.trips(page: page, limit: limit),
      fallbackData: [],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Get trip details with buffer fallback
  /// GET /trips/{id}
  Future<Trip?> getTripDetails(String tripId) async {
    return _buffer.withOptionalBuffer<Trip>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getUniqueTripsFromTrip,
          queryParams: {'tripUniqueIdentity': tripId},
        );

        if (response is List) {
          if (response.isEmpty) {
            throw NotFoundException(message: 'Trip not found');
          }
          return Trip.fromJson(response.first as Map<String, dynamic>);
        }

        if (response is! Map) {
          throw NotFoundException(message: 'Trip not found');
        }

        final data = response['data'] ?? response;
        if (data is List) {
          if (data.isEmpty) throw NotFoundException(message: 'Trip not found');
          return Trip.fromJson(data.first as Map<String, dynamic>);
        }

        return Trip.fromJson(Map<String, dynamic>.from(data as Map));
      },
      bufferKey: BufferKeys.tripDetails(tripId),
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get active trip with buffer fallback
  /// GET /api/trips/get/student/active/trip?guardianPhone={phone}
  ///
  /// The endpoint is guardian-only: it rejects any call without
  /// `guardianPhone` with a 400. Callers that have no phone (drivers) skip the
  /// request entirely and read the buffer, which is kept current by
  /// [cacheActiveTrip].
  Future<Trip?> getActiveTrip({String? guardianPhone}) async {
    if (guardianPhone == null || guardianPhone.isEmpty) {
      debugPrint('📡 No guardianPhone - reading active trip from buffer');
      return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
    }

    try {
      final queryParams = <String, String>{'guardianPhone': guardianPhone};

      debugPrint(
        '📡 Fetching active trip from: ${Endpoints.getStudentActiveTrip}',
      );
      debugPrint('📡 Query params: $queryParams');

      final response = await _apiClient.get(
        Endpoints.getStudentActiveTrip,
        queryParams: queryParams,
      );

      debugPrint('📡 Active trip response: $response');

      // Handle case where response is an empty array (no active trip)
      if (response is List) {
        if (response.isEmpty) {
          debugPrint('⚠️ Empty array response - no active trip');
          return null;
        }
        // If array has data, use first element
        final trip = Trip.fromJson(response.first as Map<String, dynamic>);
        debugPrint(
          '✅ Active trip fetched from array: ${trip.id} - ${trip.routeName}',
        );
        await _buffer.saveBuffer(
          key: BufferKeys.activeTrip,
          data: trip,
          expiration: const Duration(minutes: 5),
        );
        return trip;
      }

      // Handle map response. The API may return the trip object directly
      // (no `data` wrapper) or wrapped as {"data": {...}}.
      final map = Map<String, dynamic>.from(response as Map);
      final dynamic data = map['data'] ?? map;

      // Treat an empty object or one without any trip identifiers as
      // "no active trip" and fall back to the buffer.
      final bool hasTrip =
          data is Map &&
          data.isNotEmpty &&
          (data['tripUniqueId'] != null ||
              data['uniqueTripIdentity'] != null ||
              data['id'] != null ||
              data['masterTripId'] != null ||
              data['route'] != null ||
              data['tripName'] != null);

      if (!hasTrip) {
        debugPrint('⚠️ No active trip data in response');
        // Try to get from buffer
        final bufferedTrip = await _buffer.getBuffer<Trip>(
          key: BufferKeys.activeTrip,
        );
        if (bufferedTrip != null) {
          debugPrint('✅ Returning buffered active trip: ${bufferedTrip.id}');
        }
        return bufferedTrip;
      }

      final trip = Trip.fromJson(Map<String, dynamic>.from(data));
      debugPrint('✅ Active trip fetched: ${trip.id} - ${trip.routeName}');

      // Save to buffer
      await _buffer.saveBuffer(
        key: BufferKeys.activeTrip,
        data: trip,
        expiration: const Duration(minutes: 5),
      );

      return trip;
    } on ApiException catch (e) {
      debugPrint(
        '❌ ApiException fetching active trip: ${e.message} (status: ${e.statusCode})',
      );
      // Return from buffer on API error
      return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
    } catch (e) {
      debugPrint('❌ Error fetching active trip: $e');
      // Return from buffer on error
      return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
    }
  }

  /// Overwrite the buffered active trip with locally-updated data so the
  /// buffer fallback in [getActiveTrip] doesn't serve stale student statuses.
  Future<void> cacheActiveTrip(Trip trip) async {
    await _buffer.saveBuffer(
      key: BufferKeys.activeTrip,
      data: trip,
      expiration: const Duration(minutes: 5),
    );
  }

  /// Start a new trip (no buffer - always requires fresh API call)
  /// POST /trips/start
  Future<Trip> startTrip({
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
    try {
      // Route and vehicle IDs are unrelated to master trip IDs.
      final resolvedMasterTripId = masterTripId;
      if (resolvedMasterTripId == null || resolvedMasterTripId <= 0) {
        throw ApiException(message: 'Select a scheduled trip before starting');
      }

      final routeName = route?.trim() ?? '';
      final resolvedRoute = routeName.isNotEmpty ? routeName : routeId.trim();
      if (resolvedRoute.isEmpty) {
        throw ApiException(message: 'Select a route before starting the trip');
      }

      final response = await _apiClient.post(
        Endpoints.startTrip,
        body: {
          'masterTripId': resolvedMasterTripId,
          'tripName': tripName ?? 'Trip',
          'route': resolvedRoute,
          'driverName': driverName ?? '',
          'driverPhoneNumber': driverPhoneNumber ?? '',
          'numberPlate': numberPlate ?? vehicleId,
          'attendantName': attendantName ?? '',
          'attendantPhoneNumber': attendantPhoneNumber ?? '',
          'attendantProfileImage': attendantProfileImage ?? '',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      // Handle different API response formats
      Trip trip;
      if (response is! Map) {
        trip = Trip(
          id: response.toString().isNotEmpty
              ? response.toString()
              : resolvedMasterTripId.toString(),
          routeName: tripName ?? route ?? 'Trip',
          routeId: routeId,
          tripDirection: response['tripDirection']?.toString(),
          startTime: DateTime.now(),
          status: 'active',
          vehicleId: vehicleId,
          vehicleNumber: numberPlate,
          students: [],
          stops: [],
        );
      } else if (response['tripUniqueId'] != null ||
          response['uniqueTripIdentity'] != null) {
        // API returns tripUniqueId format - this is the ID needed for pick/drop operations
        // Store tripUniqueId as the trip ID for subsequent API calls
        trip = Trip(
          id:
              response['tripUniqueId']?.toString() ??
              response['uniqueTripIdentity']?.toString() ??
              '',
          routeName: tripName ?? route ?? 'Trip',
          routeId: routeId,
          startTime: DateTime.now(),
          status: 'active',
          vehicleId: vehicleId,
          vehicleNumber: numberPlate,
          students: (response['students'] as List? ?? [])
              .map((s) => StudentPickup.fromJson(s))
              .toList(),
          stops: [],
        );
        debugPrint('✅ Trip started with uniqueId: ${trip.id}');
      } else if (response['data'] != null) {
        // Standard wrapped response
        trip = Trip.fromJson(
          Map<String, dynamic>.from(response['data'] as Map),
        );
      } else {
        // Try to parse response directly
        trip = Trip.fromJson(Map<String, dynamic>.from(response));
      }

      // Keep the master trip id on the trip - it is the join key for the
      // driver-readable server endpoints (master trip students, unique trips).
      if (trip.masterTripId == null) {
        trip = trip.copyWith(masterTripId: resolvedMasterTripId);
      }

      // Update active trip buffer
      await _buffer.saveBuffer(
        key: BufferKeys.activeTrip,
        data: trip,
        expiration: const Duration(minutes: 5),
      );

      // Clear trips list cache to force refresh
      await _buffer.clearCategory('trips');

      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// End a trip (completes the trip)
  /// POST /api/trips/end
  ///
  /// Request body format: {'tripId': tripId, 'uniqueTripIdentity': tripId}
  /// The API requires both tripId and uniqueTripIdentity
  Future<Trip?> endTrip(
    String tripId, {
    double latitude = 0,
    double longitude = 0,
  }) async {
    try {
      // Use end trip endpoint with both tripId and uniqueTripIdentity in body
      // The API expects both fields - uniqueTripIdentity is the tripUniqueId from start trip response
      debugPrint(
        '📡 Ending trip via ${Endpoints.dropAllStudents} for uniqueTripIdentity: $tripId',
      );

      final response = await _apiClient.post(
        Endpoints.dropAllStudents,
        body: _pickDropAllBody(
          uniqueTripIdentity: tripId,
          latitude: latitude,
          longitude: longitude,
          isDroppingAll: true,
        ),
      );

      debugPrint(
        '📡 End trip response: $response (type: ${response.runtimeType})',
      );

      // Always clear buffers first - trip is ended on server side
      await _buffer.clearBuffer(BufferKeys.activeTrip);
      await _buffer.clearCategory('trips');

      final trip = parseEndTripResponse(response, tripId: tripId);
      if (trip == null) {
        debugPrint(
          '✅ Trip end acknowledged without a trip representation; '
          'preserving the local trip data',
        );
      }
      return trip;
    } on ApiException catch (e) {
      debugPrint(
        '❌ ApiException in endTrip: ${e.message} (status: ${e.statusCode})',
      );
      // Even on error, clear the active trip buffer to prevent stale data
      await _buffer.clearBuffer(BufferKeys.activeTrip);
      await _buffer.clearCategory('trips');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in endTrip: $e');
      // Even on error, clear the active trip buffer to prevent stale data
      await _buffer.clearBuffer(BufferKeys.activeTrip);
      await _buffer.clearCategory('trips');
      throw ApiException(message: e.toString());
    }
  }

  /// Parse an optional trip representation from a successful end-trip
  /// response. The backend may validly return only an acknowledgement message.
  @visibleForTesting
  static Trip? parseEndTripResponse(
    Object? response, {
    required String tripId,
    DateTime? completedAt,
  }) {
    if (response is! Map || response.isEmpty) return null;

    final data = response['data'];
    if (data is Map) {
      return Trip.fromJson(Map<String, dynamic>.from(data));
    }

    if (response['tripUniqueId'] == null && response['id'] == null) {
      return null;
    }

    final students = <StudentPickup>[];
    final rawStudents = response['students'];
    if (rawStudents is List) {
      for (final rawStudent in rawStudents) {
        if (rawStudent is Map) {
          students.add(
            StudentPickup.fromJson(Map<String, dynamic>.from(rawStudent)),
          );
        }
      }
    }

    final now = completedAt ?? DateTime.now();
    return Trip(
      id:
          response['tripUniqueId']?.toString() ??
          response['id']?.toString() ??
          tripId,
      routeName:
          response['routeName']?.toString() ??
          response['route']?.toString() ??
          '',
      routeId: response['routeId']?.toString() ?? '',
      startTime: Trip._parseDateTime(response['startTime']) ?? now,
      endTime: Trip._parseDateTime(response['endTime']) ?? now,
      status: 'completed',
      vehicleId: response['vehicleId']?.toString() ?? '',
      vehicleNumber: response['vehicleNumber']?.toString(),
      students: students,
      stops: const [],
    );
  }

  /// Update student pickup status.
  ///
  /// - `absent` → POST /api/trips/student/not/picked
  /// - `picked` / `dropped` → POST /api/trips/pick/drop/student (single student)
  ///
  /// The single-student pick/drop endpoint requires the student's registration
  /// number, the guardian's phone number and the vehicle number plate. When any
  /// of those are missing we fall back to updating local state only.
  Future<void> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status, // 'picked', 'absent', 'dropped'
    String? notes,
    double? latitude,
    double? longitude,
    String? studentReg,
    String? guardianPhoneNumber,
    String? numberPlate,
  }) async {
    try {
      final normalizedStatus = StudentPickup.normalizeStatus(status);
      if (normalizedStatus == 'absent') {
        await _apiClient.post(
          Endpoints.studentNotPicked,
          body: buildStudentNotPickedBody(
            tripUniqueIdentity: tripId,
            studentId: int.tryParse(studentId) ?? 0,
            reason: notes ?? 'Student not picked',
          ),
        );
      } else if (normalizedStatus == 'picked' ||
          normalizedStatus == 'dropped') {
        final reg = studentReg?.trim() ?? '';
        final phone = guardianPhoneNumber?.trim() ?? '';
        final plate = numberPlate?.trim() ?? '';

        if (reg.isEmpty || phone.isEmpty || plate.isEmpty) {
          debugPrint(
            'Cannot call ${Endpoints.pickDropStudent} for "$normalizedStatus" '
            '(studentReg/guardianPhoneNumber/numberPlate missing); '
            'updating local state only.',
          );
        } else {
          await _apiClient.post(
            Endpoints.pickDropStudent,
            body: buildPickSingleStudentBody(
              uniqueTripIdentity: tripId,
              studentReg: reg,
              guardianPhoneNumber: phone,
              numberPlate: plate,
              isDropping: normalizedStatus == 'dropped',
              latitude: latitude ?? 0,
              longitude: longitude ?? 0,
            ),
          );
        }
      } else {
        debugPrint(
          'No documented API endpoint for individual "$normalizedStatus" updates; updating local state only.',
        );
      }

      // Clear trip details buffer to force refresh
      await _buffer.clearBuffer(BufferKeys.tripDetails(tripId));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Pick all students in a trip
  /// POST /api/trips/pick/all
  ///
  /// Request body format: {'tripId': tripId, 'uniqueTripIdentity': tripId}
  /// The API requires both tripId and uniqueTripIdentity
  Future<void> pickAllStudents(
    String tripId, {
    double latitude = 0,
    double longitude = 0,
  }) async {
    try {
      debugPrint(
        '📡 Picking all students: POST /api/trips/pick/all with tripId: $tripId, uniqueTripIdentity: $tripId',
      );
      await _apiClient.post(
        Endpoints.pickAllStudents,
        body: _pickDropAllBody(
          uniqueTripIdentity: tripId,
          latitude: latitude,
          longitude: longitude,
          isDroppingAll: false,
        ),
      );
      // Clear trip details buffer to force refresh
      await _buffer.clearBuffer(BufferKeys.tripDetails(tripId));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Drop all students in a trip
  /// POST /api/trips/drop/all
  ///
  /// Request body format: {'tripId': tripId, 'uniqueTripIdentity': tripId}
  /// The API requires both tripId and uniqueTripIdentity
  Future<void> dropAllStudents(
    String tripId, {
    double latitude = 0,
    double longitude = 0,
  }) async {
    try {
      debugPrint(
        '📡 Dropping all students: POST /api/trips/drop/all with tripId: $tripId, uniqueTripIdentity: $tripId',
      );
      await _apiClient.post(
        Endpoints.dropAllStudents,
        body: _pickDropAllBody(
          uniqueTripIdentity: tripId,
          latitude: latitude,
          longitude: longitude,
          isDroppingAll: true,
        ),
      );
      // Clear trip details buffer to force refresh
      await _buffer.clearBuffer(BufferKeys.tripDetails(tripId));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Refresh trips cache in background
  Future<void> refreshTripsCache({int page = 1, int limit = 20}) async {
    await _buffer.refreshBuffer<List<Trip>>(
      apiCall: () => getTrips(page: page, limit: limit),
      bufferKey: BufferKeys.trips(page: page, limit: limit),
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Clear all trip-related buffers
  Future<void> clearTripBuffers() async {
    await _buffer.clearCategory('trips');
  }

  // ============================================================================
  // MASTER TRIPS ENDPOINTS
  // ============================================================================

  /// Get master trips for a specific driver with retry logic
  /// Uses getAllMasterTrips and filters by driver ID (createdBy field)
  Future<List<MasterTrip>> getMasterTripsByDriver(String driverId) async {
    return _buffer.withBuffer<List<MasterTrip>>(
      apiCall: () async {
        // Retry logic with shorter timeout
        const maxRetries = 2;
        const timeout = Duration(seconds: 15);

        for (int attempt = 0; attempt < maxRetries; attempt++) {
          try {
            if (kDebugMode && attempt > 0) {
              print('🔄 Master trips retry attempt ${attempt + 1}/$maxRetries');
            }

            // Fetch all master trips and filter by driver ID
            final response = await _apiClient.get(
              Endpoints.getAllMasterTrips,
              timeout: timeout,
            );

            final tripsData = ApiClient.unwrapList(response);

            // Filter trips by createdBy (driver ID) - exact match
            final trips = tripsData
                .map((trip) => MasterTrip.fromJson(trip))
                .where((trip) => trip.createdBy == driverId)
                .toList();

            if (kDebugMode) {
              print('🔍 Found ${trips.length} trips for driver ID: $driverId');
              for (final trip in trips) {
                print('  - ${trip.tripName} (Route: ${trip.route})');
              }
            }

            return trips;
          } on TimeoutException {
            if (attempt == maxRetries - 1) {
              // Last attempt failed, rethrow
              throw ApiException(
                message: 'Request timed out after $maxRetries attempts',
              );
            }
            // Wait before retrying
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }

        return [];
      },
      bufferKey: 'master_trips_driver_$driverId',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 5),
    );
  }

  /// Get all master trips with retry logic
  /// GET /api/trips/get/all/master/trips
  Future<List<MasterTrip>> getAllMasterTrips() async {
    return _buffer.withBuffer<List<MasterTrip>>(
      apiCall: () async {
        // Retry logic with shorter timeout
        const maxRetries = 2;
        const timeout = Duration(seconds: 15);

        for (int attempt = 0; attempt < maxRetries; attempt++) {
          try {
            if (kDebugMode && attempt > 0) {
              print('🔄 Master trips retry attempt ${attempt + 1}/$maxRetries');
            }

            final response = await _apiClient.get(
              Endpoints.getAllMasterTrips,
              timeout: timeout,
            );

            final tripsData = ApiClient.unwrapList(response);

            final trips = tripsData
                .map((trip) => MasterTrip.fromJson(trip))
                .toList();
            return trips;
          } on TimeoutException {
            if (attempt == maxRetries - 1) {
              // Last attempt failed, rethrow
              throw ApiException(
                message: 'Request timed out after $maxRetries attempts',
              );
            }
            // Wait before retrying
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }

        return [];
      },
      bufferKey: 'master_trips_all',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get students in a master trip
  /// GET /api/trips/get/master/trip/students?masterTripId={id}
  ///
  /// Takes no guardianPhone, so drivers can call it. The rows carry
  /// `isStudentPicked` / `isStudentDropped`, which makes this the one
  /// server-side read of pick state available to a driver. Pass
  /// [forceRefresh] to bypass the 5-minute buffer when reconciling live state.
  Future<List<TripStudent>> getMasterTripStudents(
    int masterTripId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _buffer.clearBuffer('master_trip_students_$masterTripId');
    }
    return _buffer.withBuffer<List<TripStudent>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getMasterTripStudents,
          queryParams: {'masterTripId': masterTripId.toString()},
        );

        final studentsData = ApiClient.unwrapList(response);

        final students = studentsData
            .map((student) => TripStudent.fromJson(student))
            .toList();
        return students;
      },
      bufferKey: 'master_trip_students_$masterTripId',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 5),
    );
  }

  /// Get guardians of students in a master trip (for drivers)
  /// GET /api/trips/get/students/guardians/in/mastertrips?masterTripId={id}
  Future<List<TripGuardian>> getStudentsGuardiansInMasterTrips(
    int masterTripId,
  ) async {
    return _buffer.withBuffer<List<TripGuardian>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getStudentsGuardiansInMasterTrips,
          queryParams: {'masterTripId': masterTripId.toString()},
        );

        final guardiansData = ApiClient.unwrapList(response);

        final guardians = guardiansData
            .map((guardian) => TripGuardian.fromJson(guardian))
            .toList();
        return guardians;
      },
      bufferKey: 'master_trip_guardians_$masterTripId',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 5),
    );
  }

  /// Create a new master trip
  /// POST /api/trips/master/create
  Future<MasterTrip> createMasterTrip({
    required String tripName,
    required String tripTime,
    required String tripDirection,
    required String route,
    required String numberPlate,
    required String attendantName,
    required String driverName,
  }) async {
    try {
      final response = await _apiClient.post(
        Endpoints.createMasterTrip,
        body: {
          'tripName': tripName,
          'tripTime': tripTime,
          'tripDirection': tripDirection,
          'route': route,
          'numberPlate': numberPlate,
          'attendantName': attendantName,
          'driverName': driverName,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final trip = response is Map
          ? MasterTrip.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : MasterTrip(
              id: 0,
              tripName: tripName,
              tripTime: tripTime,
              tripType: '',
              tripDirection: tripDirection,
              route: route,
              createdBy: '',
              schoolname: '',
              adminUserId: '',
              isTripActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              driverName: driverName,
              numberPlate: numberPlate,
              attendantName: attendantName,
            );

      // Clear master trips cache to force refresh
      await _buffer.clearCategory('master_trips');

      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Edit an existing master trip
  /// PUT /api/trips/edit/master/trip?id={tripId}
  /// Some APIs require ID as query parameter
  Future<MasterTrip> editMasterTrip({
    required int tripId,
    String? tripName,
    String? tripTime,
    String? tripDirection,
    String? route,
    String? numberPlate,
    String? attendantName,
    String? driverName,
  }) async {
    try {
      MasterTrip? currentTrip;
      final trips = await getAllMasterTrips();
      for (final trip in trips) {
        if (trip.id == tripId) {
          currentTrip = trip;
          break;
        }
      }

      final body = <String, dynamic>{
        'id': tripId,
        'tripName': tripName ?? currentTrip?.tripName ?? '',
        'tripTime': tripTime ?? currentTrip?.tripTime ?? '',
        'tripType': currentTrip?.tripType ?? '',
        'tripDirection': tripDirection ?? currentTrip?.tripDirection ?? '',
        'route': route ?? currentTrip?.route ?? '',
        'createdBy': currentTrip?.createdBy ?? '',
        'schoolname': currentTrip?.schoolname ?? '',
        'adminUserId': currentTrip?.adminUserId ?? '',
        'isTripActive': currentTrip?.isTripActive ?? true,
        'createdAt':
            currentTrip?.createdAt.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      debugPrint(
        '✏️ Editing master trip: PUT ${Endpoints.editMasterTrip}, body: $body',
      );

      final response = await _apiClient.put(
        Endpoints.editMasterTrip,
        body: body,
      );

      final trip = response is Map
          ? MasterTrip.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : MasterTrip(
              id: tripId,
              tripName: body['tripName']?.toString() ?? '',
              tripTime: body['tripTime']?.toString() ?? '',
              tripType: body['tripType']?.toString() ?? '',
              tripDirection: body['tripDirection']?.toString() ?? '',
              route: body['route']?.toString() ?? '',
              createdBy: body['createdBy']?.toString() ?? '',
              schoolname: body['schoolname']?.toString() ?? '',
              adminUserId: body['adminUserId']?.toString() ?? '',
              isTripActive: body['isTripActive'] == true,
              createdAt: currentTrip?.createdAt ?? DateTime.now(),
              updatedAt: DateTime.now(),
              driverName: driverName ?? currentTrip?.driverName,
              numberPlate: numberPlate ?? currentTrip?.numberPlate,
              attendantName: attendantName ?? currentTrip?.attendantName,
            );

      // Clear master trips cache to force refresh
      await _buffer.clearCategory('master_trips');

      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Add a student to a master trip
  /// POST /api/trips/add/student/to/master
  Future<TripStudent> addStudentToMasterTrip({
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
    try {
      final response = await _apiClient.post(
        Endpoints.addStudentToMasterTrip,
        body: {
          'masterTripId': masterTripId,
          'fullname': fullname,
          'studentRegNumber': studentRegNumber,
          'studentId': studentId,
          'guardianPhoneNumber': guardianPhoneNumber,
          'schoolname': schoolname,
          'classname': classname,
          'route': route,
          'latitude': latitude,
          'longitude': longitude,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final student = response is Map
          ? TripStudent.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : TripStudent(
              id: 0,
              masterTripId: masterTripId,
              fullname: fullname,
              studentId: studentId,
              guardianPhoneNumber: guardianPhoneNumber,
              studentRegNumber: studentRegNumber,
              schoolname: schoolname,
              transportOrg: '',
              classname: classname,
              route: route,
              latitude: latitude,
              longitude: longitude,
              pickedLatitude: 0,
              pickedLongitude: 0,
              droppedLatitude: 0,
              droppedLongitude: 0,
              isStudentPicked: false,
              isStudentDropped: false,
              profileImage: '',
              address: '',
              createdBy: '',
              hasStudentPaid: false,
              isStudentActive: true,
              isStudentDeleted: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Clear students cache for this trip
      await _buffer.clearBuffer('master_trip_students_$masterTripId');

      return student;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Delete a master trip
  /// POST /api/trips/delete/master/trip
  Future<void> deleteMasterTrip(int tripId) async {
    try {
      await _apiClient.delete(
        '${Endpoints.deleteMasterTrip}?masterTripId=$tripId',
      );

      // Clear master trips cache
      await _buffer.clearCategory('master_trips');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Delete a student from a master trip
  /// POST /api/trips/delete/student/from/master/trip
  Future<void> deleteStudentFromMasterTrip({
    required int studentId,
    required int masterTripId,
  }) async {
    try {
      debugPrint(
        '🗑️ Deleting student from master trip: studentId=$studentId, masterTripId=$masterTripId',
      );

      final response = await _apiClient.delete(
        '${Endpoints.deleteStudentFromMasterTrip}?masterTripId=$masterTripId&studentId=$studentId',
      );

      debugPrint('✅ Delete response: $response');

      // Clear students cache for this trip
      await _buffer.clearBuffer('master_trip_students_$masterTripId');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      throw ApiException(message: e.toString());
    }
  }

  /// Notify guardians that trip has started
  /// POST /api/trips/notify/guardians/trip-started
  Future<bool> notifyGuardiansTripStarted({
    required String tripId,
    required List<String> studentIds,
    String? routeName,
    String? vehicleNumber,
  }) async {
    try {
      if (kDebugMode) {
        print(
          'No documented HTTP endpoint for trip-start guardian notifications: $tripId',
        );
      }
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error notifying guardians: $e');
      }
      throw ApiException(message: e.toString());
    }
  }

  /// Notify guardians about approaching ETA (2 minutes before)
  /// POST /api/trips/notify/guardians/eta
  Future<bool> notifyGuardiansEta({
    required String tripId,
    required String studentId,
    required String stopId,
    required String stopName,
    required int etaMinutes,
  }) async {
    try {
      if (kDebugMode) {
        print(
          'No documented HTTP endpoint for ETA notification: student $studentId at $stopName',
        );
      }
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending ETA notification: $e');
      }
      throw ApiException(message: e.toString());
    }
  }

  /// Background refreshes currently in flight, keyed by buffer key, so
  /// concurrent callers share one request instead of each firing their own.
  static final Map<String, Future<List<MasterTrip>>> _masterTripsInFlight = {};

  /// When each driver's master trips were last refreshed from the network.
  static final Map<String, DateTime> _masterTripsLastRefresh = {};

  /// Minimum gap between background refreshes of the same driver's trips.
  /// Several screens poll this on their own timers; without a floor they each
  /// hit the network on every tick.
  static const Duration _masterTripsRefreshInterval = Duration(seconds: 60);

  /// Get master trips with cache-first pattern
  /// Shows cached data immediately, then refreshes in background
  /// Returns cached trips immediately if available, then updates with fresh data via callback
  Future<List<MasterTrip>> getMasterTripsByDriverCached(
    String driverId, {
    required Function(List<MasterTrip>) onRefresh,
  }) async {
    final bufferKey = 'master_trips_driver_$driverId';

    // Try to get cached data first (as List<MasterTrip> since that's what we store)
    final cachedTrips = await _buffer.getBuffer<List<MasterTrip>>(
      key: bufferKey,
    );

    // Fetch fresh data, joining an in-flight request if one is already running
    Future<List<MasterTrip>> fetchFresh() {
      final inFlight = _masterTripsInFlight[bufferKey];
      if (inFlight != null) {
        if (kDebugMode) {
          print('⏳ Joining in-flight master trips request');
        }
        return inFlight;
      }

      final request = Future(() async {
        try {
          final freshTrips = await getMasterTripsByDriver(driverId);
          await _buffer.saveBuffer(
            key: bufferKey,
            data: freshTrips,
            expiration: const Duration(minutes: 30),
          );
          _masterTripsLastRefresh[bufferKey] = DateTime.now();
          return freshTrips;
        } finally {
          _masterTripsInFlight.remove(bufferKey);
        }
      });

      _masterTripsInFlight[bufferKey] = request;
      return request;
    }

    // Return cached data immediately if available, refreshing behind it
    if (cachedTrips != null && cachedTrips.isNotEmpty) {
      final lastRefresh = _masterTripsLastRefresh[bufferKey];
      final isFresh =
          lastRefresh != null &&
          DateTime.now().difference(lastRefresh) < _masterTripsRefreshInterval;

      if (!isFresh) {
        unawaited(() async {
          try {
            onRefresh(await fetchFresh());
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Background refresh failed: $e');
            }
          }
        }());
      }

      if (kDebugMode) {
        print('📦 Returning cached trips: ${cachedTrips.length} items');
      }
      return cachedTrips;
    }

    // No cache, wait for fresh data
    if (kDebugMode) {
      print('📡 No cache available, fetching fresh data...');
    }
    return await fetchFresh();
  }

  /// Fetch complete trip data including students and guardians
  /// This is used to pre-load all data for instant navigation
  /// Returns a map with all trip data for the PreloadedTripData model
  Future<Map<String, dynamic>> fetchCompleteTripData({
    required MasterTrip masterTrip,
    Bus? preselectedVehicle,
  }) async {
    if (kDebugMode) {
      print('🚀 Fetching complete trip data for: ${masterTrip.tripName}');
    }

    final results = await Future.wait([
      // Fetch students for this trip
      getMasterTripStudents(masterTrip.id).catchError((e) {
        if (kDebugMode) print('⚠️ Failed to load students: $e');
        return <TripStudent>[];
      }),
      // Fetch guardians for this trip
      getStudentsGuardiansInMasterTrips(masterTrip.id).catchError((e) {
        if (kDebugMode) print('⚠️ Failed to load guardians: $e');
        return <TripGuardian>[];
      }),
    ]);

    final students = results[0] as List<TripStudent>;
    final guardians = results[1] as List<TripGuardian>;

    if (kDebugMode) {
      print('✅ Complete trip data loaded:');
      print('   📊 Students: ${students.length}');
      print('   👨‍👩‍👧 Guardians: ${guardians.length}');
    }

    return {
      'masterTrip': masterTrip,
      'students': students,
      'guardians': guardians,
      'vehicle': preselectedVehicle,
      'routeId': masterTrip.route,
    };
  }

  Map<String, dynamic> _pickDropAllBody({
    required String uniqueTripIdentity,
    double latitude = 0,
    double longitude = 0,
    required bool isDroppingAll,
  }) {
    return buildPickDropAllBody(
      uniqueTripIdentity: uniqueTripIdentity,
      latitude: latitude,
      longitude: longitude,
      isDroppingAll: isDroppingAll,
    );
  }

  @visibleForTesting
  static Map<String, dynamic> buildPickDropAllBody({
    required String uniqueTripIdentity,
    double latitude = 0,
    double longitude = 0,
    required bool isDroppingAll,
    DateTime? updatedAt,
  }) {
    return {
      'uniqueTripIdentity': uniqueTripIdentity,
      'latitude': latitude,
      'longitude': longitude,
      'isDroppingAll': isDroppingAll,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  /// Body for POST /api/trips/pick/drop/student ([PickSingleStudentModel]).
  ///
  /// `action` is `picked` / `dropped`.
  @visibleForTesting
  static Map<String, dynamic> buildPickSingleStudentBody({
    required String uniqueTripIdentity,
    required String studentReg,
    required String guardianPhoneNumber,
    required String numberPlate,
    required bool isDropping,
    double latitude = 0,
    double longitude = 0,
  }) {
    return {
      'uniqueTripIdentity': uniqueTripIdentity,
      'studentReg': studentReg,
      'guardianPhoneNumber': guardianPhoneNumber,
      'numberPlate': numberPlate,
      'action': isDropping ? 'dropped' : 'picked',
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @visibleForTesting
  static Map<String, dynamic> buildStudentNotPickedBody({
    required String tripUniqueIdentity,
    required int studentId,
    String reason = 'Student not picked',
    DateTime? updatedAt,
  }) {
    return {
      'tripUniqueIdentity': tripUniqueIdentity,
      'studentId': studentId,
      'reason': reason,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}

/// Trip Model
class Trip {
  final String id;
  final String routeName;
  final String routeId;
  final int? masterTripId;
  final String? tripDirection;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'active', 'completed', 'cancelled'
  final String vehicleId;
  final String? vehicleNumber;
  final List<StudentPickup> students;
  final List<TripStop> stops;
  final double? distance;
  final double? fare;
  final String? notes;

  Trip({
    required this.id,
    required this.routeName,
    required this.routeId,
    this.masterTripId,
    this.tripDirection,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.vehicleId,
    this.vehicleNumber,
    required this.students,
    required this.stops,
    this.distance,
    this.fare,
    this.notes,
  });

  Trip copyWith({
    String? id,
    String? routeName,
    String? routeId,
    int? masterTripId,
    String? tripDirection,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? vehicleId,
    String? vehicleNumber,
    List<StudentPickup>? students,
    List<TripStop>? stops,
    double? distance,
    double? fare,
    String? notes,
  }) {
    return Trip(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      routeId: routeId ?? this.routeId,
      masterTripId: masterTripId ?? this.masterTripId,
      tripDirection: tripDirection ?? this.tripDirection,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      students: students ?? this.students,
      stops: stops ?? this.stops,
      distance: distance ?? this.distance,
      fare: fare ?? this.fare,
      notes: notes ?? this.notes,
    );
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id:
          json['tripUniqueId']?.toString() ??
          json['uniqueTripIdentity']?.toString() ??
          json['id']?.toString() ??
          '',
      routeName:
          json['route_name']?.toString() ??
          json['routeName']?.toString() ??
          json['tripName']?.toString() ??
          json['route']?.toString() ??
          '',
      routeId:
          json['route_id']?.toString() ??
          json['routeId']?.toString() ??
          json['masterTripId']?.toString() ??
          json['route']?.toString() ??
          '',
      masterTripId: _parseInt(json['masterTripId']),
      tripDirection:
          json['tripDirection']?.toString() ??
          json['trip_direction']?.toString(),
      startTime:
          _parseDateTime(
            json['start_time'] ?? json['startTime'] ?? json['createdAt'],
          ) ??
          DateTime.now(),
      endTime: _parseDateTime(json['end_time'] ?? json['endTime']),
      status: normalizeTripStatus(
        json['status']?.toString() ??
            (json['isTripActive'] == false ? 'completed' : 'active'),
      ),
      vehicleId:
          json['vehicle_id']?.toString() ??
          json['vehicleId']?.toString() ??
          json['numberPlate']?.toString() ??
          '',
      vehicleNumber:
          json['vehicle_number']?.toString() ??
          json['vehicleNumber']?.toString() ??
          json['numberPlate']?.toString(),
      students:
          (json['students'] as List?)
              ?.map((s) => StudentPickup.fromJson(s))
              .toList() ??
          [],
      stops:
          (json['stops'] as List?)?.map((s) => TripStop.fromJson(s)).toList() ??
          [],
      distance: (json['distance'] as num?)?.toDouble(),
      fare: (json['fare'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_name': routeName,
      'route_id': routeId,
      'masterTripId': masterTripId,
      'tripDirection': tripDirection,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'vehicle_id': vehicleId,
      'vehicle_number': vehicleNumber,
      'students': students.map((s) => s.toJson()).toList(),
      'stops': stops.map((s) => s.toJson()).toList(),
      'distance': distance,
      'fare': fare,
      'notes': notes,
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  int get pickedCount => students.where((s) => s.status == 'picked').length;
  int get absentCount => students.where((s) => s.status == 'absent').length;
  int get pendingCount => students.where((s) => s.status == 'pending').length;

  static String normalizeTripStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
      case 'ongoing':
      case 'in_progress':
        return 'active';
      case 'completed':
      case 'complete':
      case 'ended':
        return 'completed';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return 'active';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      debugPrint('Failed to parse date: $value');
      return null;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// Student Pickup Model
class StudentPickup {
  final String id;
  final String? tripStudentId;
  final String name;
  final String? photo;
  final String status; // 'pending', 'picked', 'absent', 'dropped'
  final DateTime? pickupTime;
  final DateTime? dropoffTime;
  final String? notes;
  final String? parentPhone;
  final String? studentRegNumber;
  final String? className;
  final String? schoolName;
  final String? route;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? pickedLatitude;
  final double? pickedLongitude;
  final double? droppedLatitude;
  final double? droppedLongitude;
  final bool isStudentActive;

  StudentPickup({
    required this.id,
    this.tripStudentId,
    required this.name,
    this.photo,
    required this.status,
    this.pickupTime,
    this.dropoffTime,
    this.notes,
    this.parentPhone,
    this.studentRegNumber,
    this.className,
    this.schoolName,
    this.route,
    this.address,
    this.latitude,
    this.longitude,
    this.pickedLatitude,
    this.pickedLongitude,
    this.droppedLatitude,
    this.droppedLongitude,
    this.isStudentActive = true,
  });

  StudentPickup copyWith({
    String? id,
    String? tripStudentId,
    String? name,
    String? photo,
    String? status,
    DateTime? pickupTime,
    DateTime? dropoffTime,
    String? notes,
    String? parentPhone,
    String? studentRegNumber,
    String? className,
    String? schoolName,
    String? route,
    String? address,
    double? latitude,
    double? longitude,
    double? pickedLatitude,
    double? pickedLongitude,
    double? droppedLatitude,
    double? droppedLongitude,
    bool? isStudentActive,
  }) {
    return StudentPickup(
      id: id ?? this.id,
      tripStudentId: tripStudentId ?? this.tripStudentId,
      name: name ?? this.name,
      photo: photo ?? this.photo,
      status: status ?? this.status,
      pickupTime: pickupTime ?? this.pickupTime,
      dropoffTime: dropoffTime ?? this.dropoffTime,
      notes: notes ?? this.notes,
      parentPhone: parentPhone ?? this.parentPhone,
      studentRegNumber: studentRegNumber ?? this.studentRegNumber,
      className: className ?? this.className,
      schoolName: schoolName ?? this.schoolName,
      route: route ?? this.route,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pickedLatitude: pickedLatitude ?? this.pickedLatitude,
      pickedLongitude: pickedLongitude ?? this.pickedLongitude,
      droppedLatitude: droppedLatitude ?? this.droppedLatitude,
      droppedLongitude: droppedLongitude ?? this.droppedLongitude,
      isStudentActive: isStudentActive ?? this.isStudentActive,
    );
  }

  factory StudentPickup.fromJson(dynamic json) {
    // Handle corrupted data where json might be a String
    if (json is String) {
      debugPrint(
        '⚠️ StudentPickup.fromJson received String instead of Map: $json',
      );
      return StudentPickup(id: '', name: json, status: 'pending');
    }

    // Ensure json is a Map
    if (json is! Map<String, dynamic>) {
      debugPrint(
        '⚠️ StudentPickup.fromJson received unexpected type: ${json.runtimeType}',
      );
      return StudentPickup(id: '', name: 'Unknown Student', status: 'pending');
    }

    // Determine status from various API response formats
    String studentStatus = 'pending';
    if (json['isStudentPicked'] == true || json['isStudentDropped'] == true) {
      studentStatus = json['isStudentDropped'] == true ? 'dropped' : 'picked';
    } else if (json['status'] != null) {
      studentStatus = json['status'].toString();
    } else if (json['isStudentActive'] == false) {
      studentStatus = 'absent';
    }
    studentStatus = normalizeStatus(studentStatus);

    // Extract name with defensive handling for corrupted data
    String studentName = json['fullname'] ?? json['name'] ?? '';
    // Handle case where API returns 'string' as a placeholder/type indicator
    if (studentName == 'string' || studentName.isEmpty) {
      // Try to use studentRegNumber or studentId as fallback, but only if they look valid
      final studentReg = json['studentRegNumber']?.toString() ?? '';
      if (studentReg.isNotEmpty &&
          studentReg != 'string' &&
          studentReg != '0') {
        studentName = studentReg;
      } else {
        final studentId = json['studentId']?.toString() ?? '';
        if (studentId.isNotEmpty && studentId != 'string' && studentId != '0') {
          studentName = 'Student $studentId';
        } else {
          studentName = 'Unknown Student';
        }
      }
    }

    return StudentPickup(
      id: json['studentId']?.toString() ?? json['id']?.toString() ?? '',
      tripStudentId: json['id']?.toString(),
      name: studentName,
      photo: json['profileImage'] ?? json['photo'],
      status: studentStatus,
      pickupTime: Trip._parseDateTime(
        json['pickedTime'] ?? json['pickup_time'] ?? json['pickupTime'],
      ),
      dropoffTime: Trip._parseDateTime(
        json['dropTime'] ?? json['dropoff_time'] ?? json['dropoffTime'],
      ),
      notes: json['notes'],
      parentPhone:
          json['guardianPhoneNumber'] ??
          json['parent_phone'] ??
          json['parentPhone'],
      studentRegNumber: json['studentRegNumber']?.toString(),
      className: json['classname']?.toString() ?? json['className']?.toString(),
      schoolName:
          json['schoolname']?.toString() ?? json['schoolName']?.toString(),
      route: json['route']?.toString(),
      address: json['address']?.toString(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      pickedLatitude: _parseDouble(json['pickedLatitude']),
      pickedLongitude: _parseDouble(json['pickedLongitude']),
      droppedLatitude: _parseDouble(json['droppedLatitude']),
      droppedLongitude: _parseDouble(json['droppedLongitude']),
      isStudentActive: json['isStudentActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': int.tryParse(id) ?? id,
      'tripStudentId': tripStudentId,
      'name': name,
      'fullname': name,
      'photo': photo,
      'profileImage': photo,
      'status': status,
      'pickup_time': pickupTime?.toIso8601String(),
      'dropoff_time': dropoffTime?.toIso8601String(),
      'notes': notes,
      'parent_phone': parentPhone,
      'guardianPhoneNumber': parentPhone,
      'studentRegNumber': studentRegNumber,
      'classname': className,
      'schoolname': schoolName,
      'route': route,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'pickedLatitude': pickedLatitude,
      'pickedLongitude': pickedLongitude,
      'droppedLatitude': droppedLatitude,
      'droppedLongitude': droppedLongitude,
      'isStudentActive': isStudentActive,
    };
  }

  bool get hasPickupLocation => _hasValidCoordinate(latitude, longitude);

  bool get hasSavedHomeDestination =>
      _hasValidCoordinate(pickedLatitude, pickedLongitude) ||
      _hasValidCoordinate(latitude, longitude);

  double? get homeLatitude =>
      _hasValidCoordinate(pickedLatitude, pickedLongitude)
      ? pickedLatitude
      : latitude;

  double? get homeLongitude =>
      _hasValidCoordinate(pickedLatitude, pickedLongitude)
      ? pickedLongitude
      : longitude;

  static String normalizeStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'picked':
      case 'picked_up':
      case 'pickup':
        return 'picked';
      case 'dropped':
      case 'dropped_off':
      case 'dropoff':
        return 'dropped';
      case 'absent':
      case 'inactive':
      case 'not_available':
        return 'absent';
      default:
        return 'pending';
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _hasValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    return latitude != 0 && longitude != 0;
  }
}

/// Trip Stop Model
class TripStop {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final int order;
  final DateTime? estimatedTime;
  final DateTime? actualTime;
  final String? type; // 'pickup', 'dropoff'

  TripStop({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.order,
    this.estimatedTime,
    this.actualTime,
    this.type,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      order: json['order'] ?? 0,
      estimatedTime: Trip._parseDateTime(
        json['estimated_time'] ?? json['estimatedTime'],
      ),
      actualTime: Trip._parseDateTime(
        json['actual_time'] ?? json['actualTime'],
      ),
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'estimated_time': estimatedTime?.toIso8601String(),
      'actual_time': actualTime?.toIso8601String(),
      'type': type,
    };
  }
}
