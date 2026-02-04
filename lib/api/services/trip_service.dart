import '../api_client.dart';
import '../api_constants.dart';
import '../api_exceptions.dart';

/// Trip Service - Handles trip-related API calls
class TripService {
  final ApiClient _apiClient = ApiClient();
  
  /// Get all trips
  /// GET /trips
  Future<List<Trip>> getTrips({int page = 1, int limit = 20}) async {
    try {
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
        // Response is already a list
        tripsData = response;
      } else if (response is Map && response['data'] != null) {
        // Response is wrapped in a map with 'data' key
        tripsData = response['data'] as List;
      } else {
        // Empty or unknown response structure
        tripsData = [];
      }
      
      final trips = tripsData.map((trip) => Trip.fromJson(trip)).toList();
      return trips;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get trip details
  /// GET /trips/{id}
  Future<Trip> getTripDetails(String tripId) async {
    try {
      final endpoint = ApiConstants.tripDetails.replaceAll('{id}', tripId);
      final response = await _apiClient.get(endpoint);
      
      return Trip.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get active trip
  /// GET /trips/active
  Future<Trip?> getActiveTrip() async {
    try {
      final response = await _apiClient.get(ApiConstants.activeTrip);
      
      if (response['data'] == null) {
        return null;
      }
      
      return Trip.fromJson(response['data']);
    } on NotFoundException {
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Start a new trip
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
      
      return Trip.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// End a trip
  /// POST /trips/{id}/end
  Future<Trip> endTrip(String tripId) async {
    try {
      final endpoint = ApiConstants.endTrip.replaceAll('{id}', tripId);
      final response = await _apiClient.post(endpoint);
      
      return Trip.fromJson(response['data']);
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
      routeName: json['route_name'] ?? '',
      routeId: json['route_id'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time']) 
          : null,
      status: json['status'] ?? 'active',
      vehicleId: json['vehicle_id'] ?? '',
      vehicleNumber: json['vehicle_number'],
      students: (json['students'] as List?)
          ?.map((s) => StudentPickup.fromJson(s))
          .toList() ?? [],
      stops: (json['stops'] as List?)
          ?.map((s) => TripStop.fromJson(s))
          .toList() ?? [],
      distance: json['distance']?.toDouble(),
      fare: json['fare']?.toDouble(),
      notes: json['notes'],
    );
  }
  
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  
  int get pickedCount => students.where((s) => s.status == 'picked').length;
  int get absentCount => students.where((s) => s.status == 'absent').length;
  int get pendingCount => students.where((s) => s.status == 'pending').length;
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      photo: json['photo'],
      status: json['status'] ?? 'pending',
      pickupTime: json['pickup_time'] != null 
          ? DateTime.parse(json['pickup_time']) 
          : null,
      dropoffTime: json['dropoff_time'] != null 
          ? DateTime.parse(json['dropoff_time']) 
          : null,
      notes: json['notes'],
      parentPhone: json['parent_phone'],
    );
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      order: json['order'] ?? 0,
      estimatedTime: json['estimated_time'] != null 
          ? DateTime.parse(json['estimated_time']) 
          : null,
      actualTime: json['actual_time'] != null 
          ? DateTime.parse(json['actual_time']) 
          : null,
      type: json['type'],
    );
  }
}
