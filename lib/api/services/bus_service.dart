import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';

/// Bus Service - Handles bus/vehicle-related API calls with fallback buffers
class BusService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();
  
  /// Get all buses with buffer fallback
  /// GET /api/buses/get/all
  Future<List<Bus>> getAllBuses() async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
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
      },
      bufferKey: BufferKeys.buses,
      fallbackData: <Bus>[],
      cacheDuration: const Duration(minutes: 30),
    );
  }
  
  /// Get buses by user with buffer fallback
  /// GET /api/buses/get/by/user
  Future<List<Bus>> getBusesByUser() async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
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
      },
      bufferKey: '${BufferKeys.buses}_by_user',
      fallbackData: <Bus>[],
      cacheDuration: const Duration(minutes: 30),
    );
  }
  
  /// Get active buses with buffer fallback
  /// GET /api/buses/get/active
  Future<List<Bus>> getActiveBuses() async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getActiveBuses);
        
        final buses = (response['data'] as List? ?? [])
            .map((bus) => Bus.fromJson(bus))
            .toList();
        
        return buses;
      },
      bufferKey: '${BufferKeys.buses}_active',
      fallbackData: <Bus>[],
      cacheDuration: const Duration(minutes: 10), // Short cache for active buses
    );
  }
  
  /// Get bus by ID with buffer fallback
  /// GET /api/buses/get/{id}
  Future<Bus?> getBusById(String busId) async {
    return _buffer.withOptionalBuffer<Bus>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getBusById(busId));
        return Bus.fromJson(response['data'] ?? response);
      },
      bufferKey: BufferKeys.busDetails(busId),
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Refresh buses cache in background
  Future<void> refreshBusesCache() async {
    await _buffer.refreshBuffer<List<Bus>>(
      apiCall: () => getAllBuses(),
      bufferKey: BufferKeys.buses,
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Clear all bus-related buffers
  Future<void> clearBusBuffers() async {
    await _buffer.clearCategory('buses');
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
      id: json['id']?.toString() ?? '',
      registrationNumber: json['registration_number'] ?? json['registrationNumber'] ?? '',
      model: json['model'],
      capacity: json['capacity']?.toString(),
      schoolId: json['school_id'] ?? json['schoolId'],
      schoolName: json['school_name'] ?? json['schoolName'],
      driverId: json['driver_id'] ?? json['driverId'],
      driverName: json['driver_name'] ?? json['driverName'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
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
