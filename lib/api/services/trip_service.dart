import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_constants.dart';
import '../api_exceptions.dart';
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
          queryParams: {
            'page': page.toString(),
            'limit': limit.toString(),
          },
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
  /// GET /trips/active
  Future<Trip?> getActiveTrip() async {
    try {
      final response = await _apiClient.get(ApiConstants.activeTrip);
      
      if (response['data'] == null) {
        // Try to get from buffer
        return await _buffer.getBuffer<Trip>(key: BufferKeys.activeTrip);
      }
      
      final trip = Trip.fromJson(response['data']);
      
      // Save to buffer
      await _buffer.saveBuffer(
        key: BufferKeys.activeTrip,
        data: trip,
        expiration: const Duration(minutes: 5),
      );
      
      return trip;
    } catch (e) {
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
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.startTrip,
        body: {
          'route_id': routeId,
          'vehicle_id': vehicleId,
          if (studentIds != null) 'student_ids': studentIds,
        },
      );
      
      final trip = Trip.fromJson(response['data']);
      
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
  
  /// End a trip (no buffer - always requires fresh API call)
  /// POST /trips/{id}/end
  Future<Trip> endTrip(String tripId) async {
    try {
      final endpoint = ApiConstants.endTrip.replaceAll('{id}', tripId);
      final response = await _apiClient.post(endpoint);
      
      final trip = Trip.fromJson(response['data']);
      
      // Clear active trip buffer
      await _buffer.clearBuffer(BufferKeys.activeTrip);
      
      // Clear trips list cache
      await _buffer.clearCategory('trips');
      
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
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
        body: {
          'status': status,
          if (notes != null) 'notes': notes,
        },
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
      startTime: _parseDateTime(json['start_time'] ?? json['startTime']) ?? DateTime.now(),
      endTime: _parseDateTime(json['end_time'] ?? json['endTime']),
      status: json['status'] ?? 'active',
      vehicleId: json['vehicle_id'] ?? json['vehicleId'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
      students: (json['students'] as List?)
          ?.map((s) => StudentPickup.fromJson(s))
          .toList() ?? [],
      stops: (json['stops'] as List?)
          ?.map((s) => TripStop.fromJson(s))
          .toList() ?? [],
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
  
  factory StudentPickup.fromJson(Map<String, dynamic> json) {
    return StudentPickup(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      photo: json['photo'],
      status: json['status'] ?? 'pending',
      pickupTime: Trip._parseDateTime(json['pickup_time'] ?? json['pickupTime']),
      dropoffTime: Trip._parseDateTime(json['dropoff_time'] ?? json['dropoffTime']),
      notes: json['notes'],
      parentPhone: json['parent_phone'] ?? json['parentPhone'],
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
      estimatedTime: Trip._parseDateTime(json['estimated_time'] ?? json['estimatedTime']),
      actualTime: Trip._parseDateTime(json['actual_time'] ?? json['actualTime']),
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
