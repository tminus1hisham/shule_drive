import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_constants.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../models/master_trip.dart';
import '../../utils/buffer_manager.dart';

/// Trip Service - Handles trip-related API calls with fallback buffers
class TripService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get all trips with buffer fallback
  /// GET /trips
  Future<List<Trip>> getTrips({int page = 1, int limit = 20}) async {
    return _buffer.withBuffer<List<Trip>>(
      apiCall: () async {
        final response = await _apiClient.get(
          ApiConstants.trips,
          queryParams: {'page': page.toString(), 'limit': limit.toString()},
        );

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> tripsData;
        if (response is List) {
          tripsData = response;
        } else if (response is Map && response['data'] != null) {
          tripsData = response['data'] as List;
        } else {
          tripsData = [];
        }

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
        final endpoint = ApiConstants.tripDetails.replaceAll('{id}', tripId);
        final response = await _apiClient.get(endpoint);
        return Trip.fromJson(response['data'] ?? response);
      },
      bufferKey: BufferKeys.tripDetails(tripId),
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get active trip with buffer fallback
  /// GET /api/trips/get/student/active/trip?guardianPhone={phone}
  Future<Trip?> getActiveTrip({String? guardianPhone}) async {
    try {
      final queryParams = <String, String>{};
      if (guardianPhone != null && guardianPhone.isNotEmpty) {
        queryParams['guardianPhone'] = guardianPhone;
      }

      debugPrint('📡 Fetching active trip from: ${ApiConstants.activeTrip}');
      debugPrint('📡 Query params: $queryParams');

      final response = await _apiClient.get(
        ApiConstants.activeTrip,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
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
        debugPrint('✅ Active trip fetched from array: ${trip.id} - ${trip.routeName}');
        await _buffer.saveBuffer(
          key: BufferKeys.activeTrip,
          data: trip,
          expiration: const Duration(minutes: 5),
        );
        return trip;
      }

      // Handle normal map response
      if (response['data'] == null) {
        debugPrint('⚠️ No active trip data in response');
        // Try to get from buffer
        final bufferedTrip = await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
        if (bufferedTrip != null) {
          debugPrint('✅ Returning buffered active trip: ${bufferedTrip.id}');
        }
        return bufferedTrip;
      }

      final trip = Trip.fromJson(response['data']);
      debugPrint('✅ Active trip fetched: ${trip.id} - ${trip.routeName}');

      // Save to buffer
      await _buffer.saveBuffer(
        key: BufferKeys.activeTrip,
        data: trip,
        expiration: const Duration(minutes: 5),
      );

      return trip;
    } on ApiException catch (e) {
      debugPrint('❌ ApiException fetching active trip: ${e.message} (status: ${e.statusCode})');
      // Return from buffer on API error
      return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
    } catch (e) {
      debugPrint('❌ Error fetching active trip: $e');
      // Return from buffer on error
      return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
    }
  }

  /// Start a new trip (no buffer - always requires fresh API call)
  /// POST /trips/start
  Future<Trip> startTrip({
    required String routeId,
    required String vehicleId,
    List<String>? studentIds,
    String? route,
    String? tripName,
    String? driverName,
    String? numberPlate,
    String? driverPhoneNumber,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.startTrip,
        body: {
          'route_id': routeId,
          'vehicle_id': vehicleId,
          if (studentIds != null) 'student_ids': studentIds,
          if (route != null) 'Route': route,
          if (tripName != null) 'TripName': tripName,
          if (driverName != null) 'DriverName': driverName,
          if (numberPlate != null) 'NumberPlate': numberPlate,
          if (driverPhoneNumber != null) 'DriverPhoneNumber': driverPhoneNumber,
        },
      );

      // Handle different API response formats
      Trip trip;
      if (response['data'] != null) {
        // Standard wrapped response
        trip = Trip.fromJson(response['data']);
      } else if (response['tripUniqueId'] != null) {
        // API returns tripUniqueId format - construct Trip from response
        trip = Trip(
          id: response['tripUniqueId']?.toString() ?? '',
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
      } else {
        // Try to parse response directly
        trip = Trip.fromJson(response);
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
  Future<Trip> endTrip(String tripId) async {
    try {
      // Use end trip endpoint with tripId in body
      // The API expects the tripId in the request body, not URL path
      debugPrint('📡 Ending trip: POST /api/trips/end with tripId: $tripId');
      
      final response = await _apiClient.post(
        '/api/trips/end',
        body: {'tripId': tripId},
      );

      debugPrint('📡 End trip response: $response (type: ${response.runtimeType})');

      // Always clear buffers first - trip is ended on server side
      await _buffer.clearBuffer(BufferKeys.activeTrip);
      await _buffer.clearCategory('trips');

      // Handle null or empty response (server returned 200 with empty body)
      if (response == null || (response is Map && response.isEmpty)) {
        debugPrint('⚠️ Server returned empty/null response, creating minimal trip object');
        return Trip(
          id: tripId,
          routeName: 'Trip',
          routeId: '',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          status: 'completed',
          vehicleId: '',
          // Note: Students will be empty - caller should preserve original student data
          students: [],
          stops: [],
        );
      }

      // Handle different response formats
      Trip trip;
      if (response['data'] != null) {
        trip = Trip.fromJson(response['data']);
      } else if (response['tripUniqueId'] != null || response['id'] != null) {
        // Try to parse students from response if available
        List<StudentPickup> students = [];
        if (response['students'] != null && response['students'] is List) {
          students = (response['students'] as List)
              .map((s) => StudentPickup.fromJson(s))
              .toList();
        }
        
        // Construct trip from response
        trip = Trip(
          id: response['tripUniqueId']?.toString() ?? response['id']?.toString() ?? tripId,
          routeName: response['routeName'] ?? response['route'] ?? 'Trip',
          routeId: response['routeId']?.toString() ?? '',
          startTime: Trip._parseDateTime(response['startTime']) ?? DateTime.now(),
          endTime: Trip._parseDateTime(response['endTime']) ?? DateTime.now(),
          status: 'completed',
          vehicleId: response['vehicleId']?.toString() ?? '',
          vehicleNumber: response['vehicleNumber']?.toString(),
          students: students, // Use parsed students if available
          stops: [],
        );
      } else {
        // Return a minimal trip object for any other response format
        debugPrint('⚠️ Unexpected response format, creating minimal trip object');
        trip = Trip(
          id: tripId,
          routeName: 'Trip',
          routeId: '',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          status: 'completed',
          vehicleId: '',
          students: [],
          stops: [],
        );
      }

      return trip;
    } on ApiException catch (e) {
      debugPrint('❌ ApiException in endTrip: ${e.message} (status: ${e.statusCode})');
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

  /// Update student pickup status
  /// PATCH /trips/{tripId}/students/{studentId}/status
  Future<void> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status, // 'picked', 'absent', 'dropped'
    String? notes,
  }) async {
    try {
      final endpoint = '/trips/$tripId/students/$studentId/status';
      await _apiClient.patch(
        endpoint,
        body: {'status': status, if (notes != null) 'notes': notes},
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

  /// Get all master trips
  /// GET /api/trips/get/all/master/trips
  Future<List<MasterTrip>> getAllMasterTrips() async {
    return _buffer.withBuffer<List<MasterTrip>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getAllMasterTrips);

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> tripsData;
        if (response is List) {
          tripsData = response;
        } else if (response is Map && response['data'] != null) {
          tripsData = response['data'] as List;
        } else {
          tripsData = [];
        }

        final trips = tripsData
            .map((trip) => MasterTrip.fromJson(trip))
            .toList();
        return trips;
      },
      bufferKey: 'master_trips_all',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get students in a master trip
  /// GET /api/trips/get/master/trip/students?masterTripId={id}
  Future<List<TripStudent>> getMasterTripStudents(int masterTripId) async {
    return _buffer.withBuffer<List<TripStudent>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getMasterTripStudents,
          queryParams: {'masterTripId': masterTripId.toString()},
        );

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> studentsData;
        if (response is List) {
          studentsData = response;
        } else if (response is Map && response['data'] != null) {
          studentsData = response['data'] as List;
        } else {
          studentsData = [];
        }

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

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> guardiansData;
        if (response is List) {
          guardiansData = response;
        } else if (response is Map && response['data'] != null) {
          guardiansData = response['data'] as List;
        } else {
          guardiansData = [];
        }

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
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      final trip = MasterTrip.fromJson(response['data'] ?? response);

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
  /// POST /api/trips/edit/master/trip
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
      final body = <String, dynamic>{
        'id': tripId,
        if (tripName != null) 'tripName': tripName,
        if (tripTime != null) 'tripTime': tripTime,
        if (tripDirection != null) 'tripDirection': tripDirection,
        if (route != null) 'route': route,
        if (numberPlate != null) 'numberPlate': numberPlate,
        if (attendantName != null) 'attendantName': attendantName,
        if (driverName != null) 'driverName': driverName,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final response = await _apiClient.post(
        Endpoints.editMasterTrip,
        body: body,
      );

      final trip = MasterTrip.fromJson(response['data'] ?? response);

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
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      final student = TripStudent.fromJson(response['data'] ?? response);

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
      await _apiClient.post(
        Endpoints.deleteMasterTrip,
        body: {'id': tripId},
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
    required int studentTripId,
    required int masterTripId,
  }) async {
    try {
      await _apiClient.post(
        Endpoints.deleteStudentFromMasterTrip,
        body: {
          'id': studentTripId,
          'masterTripId': masterTripId,
        },
      );

      // Clear students cache for this trip
      await _buffer.clearBuffer('master_trip_students_$masterTripId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
}

/// Trip Model
class Trip {
  final String id;
  final String routeName;
  final String routeId;
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

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      routeName: json['route_name'] ?? json['routeName'] ?? '',
      routeId: json['route_id'] ?? json['routeId'] ?? '',
      startTime:
          _parseDateTime(json['start_time'] ?? json['startTime']) ??
          DateTime.now(),
      endTime: _parseDateTime(json['end_time'] ?? json['endTime']),
      status: json['status'] ?? 'active',
      vehicleId: json['vehicle_id'] ?? json['vehicleId'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
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
}

/// Student Pickup Model
class StudentPickup {
  final String id;
  final String name;
  final String? photo;
  final String status; // 'pending', 'picked', 'absent', 'dropped'
  final DateTime? pickupTime;
  final DateTime? dropoffTime;
  final String? notes;
  final String? parentPhone;

  StudentPickup({
    required this.id,
    required this.name,
    this.photo,
    required this.status,
    this.pickupTime,
    this.dropoffTime,
    this.notes,
    this.parentPhone,
  });

  factory StudentPickup.fromJson(dynamic json) {
    // Handle corrupted data where json might be a String
    if (json is String) {
      debugPrint('⚠️ StudentPickup.fromJson received String instead of Map: $json');
      return StudentPickup(
        id: '',
        name: json,
        status: 'pending',
      );
    }
    
    // Ensure json is a Map
    if (json is! Map<String, dynamic>) {
      debugPrint('⚠️ StudentPickup.fromJson received unexpected type: ${json.runtimeType}');
      return StudentPickup(
        id: '',
        name: 'Unknown Student',
        status: 'pending',
      );
    }
    
    // Determine status from various API response formats
    String studentStatus = 'pending';
    if (json['isStudentPicked'] == true || json['isStudentDropped'] == true) {
      studentStatus = json['isStudentDropped'] == true ? 'dropped' : 'picked';
    } else if (json['status'] != null) {
      studentStatus = json['status'];
    }

    return StudentPickup(
      id: json['id']?.toString() ?? json['studentId']?.toString() ?? '',
      name: json['fullname'] ?? json['name'] ?? '',
      photo: json['profileImage'] ?? json['photo'],
      status: studentStatus,
      pickupTime: Trip._parseDateTime(
        json['pickedTime'] ?? json['pickup_time'] ?? json['pickupTime'],
      ),
      dropoffTime: Trip._parseDateTime(
        json['dropTime'] ?? json['dropoff_time'] ?? json['dropoffTime'],
      ),
      notes: json['notes'],
      parentPhone: json['guardianPhoneNumber'] ?? json['parent_phone'] ?? json['parentPhone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
      'status': status,
      'pickup_time': pickupTime?.toIso8601String(),
      'dropoff_time': dropoffTime?.toIso8601String(),
      'notes': notes,
      'parent_phone': parentPhone,
    };
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
