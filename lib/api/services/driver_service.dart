import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../endpoints.dart';
import '../../models/driver.dart';
import '../../utils/buffer_manager.dart';

// Re-export so existing `driver_service.Driver` consumers keep working.
export '../../models/driver.dart';

/// Driver Service - Handles driver-related API calls
class DriverService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get driver by ID
  /// GET /api/drivers/get/by/{id}
  Future<Driver?> getDriverById(String driverId) async {
    try {
      final response = await _apiClient.get(Endpoints.getDriverById(driverId));

      // Handle both wrapped ({"data": {...}}) and unwrapped ({...}) responses
      final driverData = ApiClient.unwrapObject(response);
      if (driverData != null) {
        return Driver.fromJson(driverData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching driver by ID: $e');
      }
      return null;
    }
  }

  /// Get current driver's details for the authenticated user
  /// GET /api/drivers/get/by/user
  Future<Driver?> getCurrentDriver(String userId) async {
    try {
      if (kDebugMode) {
        print('🚗 Fetching driver details for user: $userId');
      }

      // Use /api/drivers/get/by/user to get the driver's own record
      final response = await _apiClient.get(Endpoints.getDriversByUser);

      // Handle both wrapped ({"data": {...}}) and unwrapped ({...}) responses
      final driverData = ApiClient.unwrapObject(response);
      if (driverData != null) {
        final driver = Driver.fromJson(driverData);
        if (kDebugMode) {
          print('✅ Driver found:');
          print('   Name: ${driver.name}');
          print('   School ID: ${driver.schoolId}');
          print('   School Name: ${driver.schoolName}');
        }
        return driver;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching driver: $e');
      }
      return null;
    }
  }

  /// Get drivers by school
  /// GET /api/drivers/get/by/school/{schoolId}
  Future<List<Driver>> getDriversBySchool(String schoolId) async {
    return _buffer.withBuffer<List<Driver>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getDriversBySchool(schoolId),
        );

        final driversData = ApiClient.unwrapList(response);

        final drivers = driversData
            .map((driver) => Driver.fromJson(driver))
            .toList();

        return drivers;
      },
      bufferKey: 'drivers_school_$schoolId',
      fallbackData: <Driver>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Clear driver-related buffers
  Future<void> clearDriverBuffers() async {
    await _buffer.clearCategory('drivers');
  }
}
