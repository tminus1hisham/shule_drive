import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';

/// Bus Service - Handles bus/vehicle-related API calls
class BusService {
  final ApiClient _apiClient = ApiClient();
  
  /// Get all buses
  /// GET /api/buses/get/all
  Future<List<Bus>> getAllBuses() async {
    try {
      final response = await _apiClient.get(Endpoints.getAllBuses);
      
      // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
      List<dynamic> busesData;
      if (response is List) {
        busesData = response;
      } else if (response is Map && response['data'] != null) {
        busesData = response['data'] as List;
      } else {
        busesData = [];
      }
      
      final buses = busesData.map((bus) => Bus.fromJson(bus)).toList();
      return buses;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get buses by user
  /// GET /api/buses/get/by/user
  Future<List<Bus>> getBusesByUser() async {
    try {
      final response = await _apiClient.get(Endpoints.getBusesByUser);
      
      // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
      List<dynamic> busesData;
      if (response is List) {
        busesData = response;
      } else if (response is Map && response['data'] != null) {
        busesData = response['data'] as List;
      } else {
        busesData = [];
      }
      
      final buses = busesData.map((bus) => Bus.fromJson(bus)).toList();
      return buses;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get active buses
  /// GET /api/buses/get/active
  Future<List<Bus>> getActiveBuses() async {
    try {
      final response = await _apiClient.get(Endpoints.getActiveBuses);
      
      final buses = (response['data'] as List)
          .map((bus) => Bus.fromJson(bus))
          .toList();
      
      return buses;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get bus by ID
  /// GET /api/buses/get/{id}
  Future<Bus> getBusById(String busId) async {
    try {
      final response = await _apiClient.get(Endpoints.getBusById(busId));
      
      return Bus.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
}

/// Bus Model
class Bus {
  final String id;
  final String registrationNumber;
  final String? model;
  final String? capacity;
  final String? schoolId;
  final String? schoolName;
  final String? driverId;
  final String? driverName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Bus({
    required this.id,
    required this.registrationNumber,
    this.model,
    this.capacity,
    this.schoolId,
    this.schoolName,
    this.driverId,
    this.driverName,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] ?? '',
      registrationNumber: json['registration_number'] ?? json['registrationNumber'] ?? '',
      model: json['model'],
      capacity: json['capacity']?.toString(),
      schoolId: json['school_id'],
      schoolName: json['school_name'],
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registration_number': registrationNumber,
      'model': model,
      'capacity': capacity,
      'school_id': schoolId,
      'school_name': schoolName,
      'driver_id': driverId,
      'driver_name': driverName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
