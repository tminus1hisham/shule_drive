import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';

/// Bus Service - Handles bus/vehicle-related API calls with fallback buffers
class BusService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get all buses with buffer fallback and retry logic
  /// GET /api/buses/get/all
  Future<List<Bus>> getAllBuses() async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
        // Retry logic with longer timeout for staging API
        const maxRetries = 2;
        const timeout = Duration(seconds: 30);
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
          try {
            if (kDebugMode && attempt > 0) {
              print('🔄 Buses retry attempt ${attempt + 1}/$maxRetries');
            }
            
            final response = await _apiClient.get(
              Endpoints.getAllBuses,
              timeout: timeout,
            );

            // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
            List<dynamic> busesData;
            if (response is List) {
              busesData = response;
            } else if (response is Map && response['data'] != null) {
              busesData = response['data'] as List;
            } else {
              busesData = [];
            }

            if (kDebugMode && busesData.isNotEmpty) {
              final first = busesData.first as Map<String, dynamic>;
              print('🚌 First bus raw data: $first');
              print('🚌 Available fields: ${first.keys.toList()}');
              // Print all field values for debugging
              for (final key in first.keys) {
                print('🚌 $key: ${first[key]}');
              }
            }

            final buses = busesData.map((bus) => Bus.fromJson(bus)).toList();
            return buses;
          } on TimeoutException catch (e) {
            if (attempt == maxRetries - 1) {
              // Last attempt failed, rethrow
              throw ApiException(message: 'Request timed out after $maxRetries attempts');
            }
            // Wait before retrying
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }
        
        return [];
      },
      bufferKey: BufferKeys.buses,
      fallbackData: [],
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Get buses by user with buffer fallback and retry logic
  /// GET /api/buses/get/by/user
  Future<List<Bus>> getBusesByUser() async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
        // Retry logic with longer timeout for staging API
        const maxRetries = 2;
        const timeout = Duration(seconds: 30);
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
          try {
            if (kDebugMode && attempt > 0) {
              print('🔄 Buses by user retry attempt ${attempt + 1}/$maxRetries');
            }
            
            final response = await _apiClient.get(
              Endpoints.getBusesByUser,
              timeout: timeout,
            );

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
          } on TimeoutException catch (e) {
            if (attempt == maxRetries - 1) {
              // Last attempt failed, rethrow
              throw ApiException(message: 'Request timed out after $maxRetries attempts');
            }
            // Wait before retrying
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }
        
        return [];
      },
      bufferKey: '${BufferKeys.buses}_by_user',
      fallbackData: [],
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
      fallbackData: [],
      cacheDuration: const Duration(
        minutes: 10,
      ), // Short cache for active buses
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

  /// Get buses by school ID
  /// GET /api/drivers/get/by/school/{schoolId} (returns drivers with their vehicles)
  Future<List<Bus>> getBusesBySchool(String schoolId) async {
    return _buffer.withBuffer<List<Bus>>(
      apiCall: () async {
        // Use getAllBuses and filter by schoolId client-side
        // The API doesn't have a direct endpoint for getting buses by school
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

        // Filter buses by school ID (companyOrgId field)
        final buses = busesData
            .map((bus) => Bus.fromJson(bus))
            .where((bus) => bus.schoolId == schoolId)
            .toList();

        return buses;
      },
      bufferKey: '${BufferKeys.buses}_school_$schoolId',
      fallbackData: [],
      cacheDuration: const Duration(minutes: 15),
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
      registrationNumber:
          json['numberplate'] ??
          json['numberPlate'] ??
          json['plate_number'] ??
          json['plateNumber'] ??
          json['license_plate'] ??
          json['licensePlate'] ??
          json['bus_number'] ??
          json['busNumber'] ??
          json['registration_number'] ??
          json['registrationNumber'] ??
          json['reg_number'] ??
          json['regNumber'] ??
          '',
      model: json['model'],
      capacity:
          json['seatingCapacity']?.toString() ?? json['capacity']?.toString(),
      schoolId: json['companyOrgId'] ?? json['school_id'] ?? json['schoolId'],
      schoolName: json['school_name'] ?? json['schoolName'],
      driverId: json['driver_id'] ?? json['driverId'],
      driverName: json['driver_name'] ?? json['driverName'],
      isActive:
          json['isBusActive'] ?? json['is_active'] ?? json['isActive'] ?? true,
      createdAt:
          _parseDateTime(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
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
