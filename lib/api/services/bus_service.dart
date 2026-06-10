import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../models/bus.dart';
import '../../utils/buffer_manager.dart';

// Re-export so existing `bus_service.Bus` consumers keep working.
export '../../models/bus.dart';

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

            final busesData = ApiClient.unwrapList(response);

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
              print(
                '🔄 Buses by user retry attempt ${attempt + 1}/$maxRetries',
              );
            }

            final response = await _apiClient.get(
              Endpoints.getBusesByUser,
              timeout: timeout,
            );

            final busesData = ApiClient.unwrapList(response);

            final buses = busesData.map((bus) => Bus.fromJson(bus)).toList();
            return buses;
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

        final busesData = ApiClient.unwrapList(response);

        final buses = busesData.map((bus) => Bus.fromJson(bus)).toList();

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
        final data = ApiClient.unwrapObject(response);
        if (data == null) {
          throw NotFoundException(message: 'Bus not found');
        }
        return Bus.fromJson(data);
      },
      bufferKey: BufferKeys.busDetails(busId),
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Get all buses with cache-first pattern
  /// Shows cached data immediately, then refreshes in background
  /// Returns cached buses immediately if available, then updates with fresh data via callback
  Future<List<Bus>> getAllBusesCached({
    required Function(List<Bus>) onRefresh,
  }) async {
    const bufferKey = BufferKeys.buses;

    // Try to get cached data first (as List<Bus> since that's what we store)
    final cachedBuses = await _buffer.getBuffer<List<Bus>>(key: bufferKey);

    // Fetch fresh data in background
    Future<void> fetchFresh() async {
      try {
        final freshBuses = await getAllBuses();
        // Save to cache
        await _buffer.saveBuffer(
          key: bufferKey,
          data: freshBuses,
          expiration: const Duration(minutes: 30),
        );
        // Notify with fresh data
        onRefresh(freshBuses);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Background bus refresh failed: $e');
        }
      }
    }

    // Start background fetch
    fetchFresh();

    // Return cached data immediately if available
    if (cachedBuses != null && cachedBuses.isNotEmpty) {
      if (kDebugMode) {
        print('📦 Returning cached buses: ${cachedBuses.length} items');
      }
      return cachedBuses;
    }

    // No cache, wait for fresh data
    if (kDebugMode) {
      print('📡 No cache available, fetching fresh bus data...');
    }
    final buses = await getAllBuses();
    await _buffer.saveBuffer(
      key: bufferKey,
      data: buses,
      expiration: const Duration(minutes: 30),
    );
    return buses;
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

        final busesData = ApiClient.unwrapList(response);

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
