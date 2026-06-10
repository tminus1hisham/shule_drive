import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../models/route.dart';
import '../../utils/buffer_manager.dart';

// Re-export so existing `route_service.BusRoute` / `RouteStop` consumers work.
export '../../models/route.dart';

/// Route Service - Handles route-related API calls with fallback buffers
class RouteService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get all routes with buffer fallback
  /// GET /api/routes/get/all
  Future<List<BusRoute>> getAllRoutes() async {
    return _buffer.withBuffer<List<BusRoute>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getAllRoutes);

        final routesData = ApiClient.unwrapList(response);

        if (kDebugMode && routesData.isNotEmpty) {
          print('🛣️ First route raw data: ${routesData.first}');
        }

        final routes = routesData
            .map((route) => BusRoute.fromJson(route))
            .toList();
        return routes;
      },
      bufferKey: BufferKeys.routes,
      fallbackData: <BusRoute>[],
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Get routes by user with buffer fallback
  /// GET /api/routes/get/by/user
  Future<List<BusRoute>> getRoutesByUser() async {
    return _buffer.withBuffer<List<BusRoute>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getRoutesByUser);

        final routesData = ApiClient.unwrapList(response);

        final routes = routesData
            .map((route) => BusRoute.fromJson(route))
            .toList();
        return routes;
      },
      bufferKey: '${BufferKeys.routes}_by_user',
      fallbackData: <BusRoute>[],
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Get route details with buffer fallback
  /// GET /api/routes/get/{id}
  Future<BusRoute?> getRouteById(String routeId) async {
    return _buffer.withOptionalBuffer<BusRoute>(
      apiCall: () async {
        final routes = await getAllRoutes();
        for (final route in routes) {
          if (route.id == routeId) return route;
        }
        throw NotFoundException(message: 'Route not found');
      },
      bufferKey: BufferKeys.routeDetails(routeId),
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Create a new route
  /// POST /api/routes/create
  Future<BusRoute> createRoute({
    required String name,
    required String description,
    required List<RouteStop> stops,
    String? schoolId,
  }) async {
    try {
      final schoolname = schoolId ?? description;
      if (schoolname.isEmpty) {
        throw ApiException(message: 'School name is required');
      }

      final response = await _apiClient.post(
        Endpoints.createRoute,
        body: {'schoolname': schoolname, 'routeName': name},
      );

      final route = response is Map
          ? BusRoute.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : BusRoute(
              id: '',
              name: name,
              schoolName: schoolname,
              stops: stops,
              createdAt: DateTime.now(),
            );

      // Clear routes cache to force refresh
      await _buffer.clearCategory('routes');

      return route;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Update a route
  /// PUT /api/routes/update/{id}
  Future<BusRoute> updateRoute({
    required String routeId,
    String? name,
    String? description,
    List<RouteStop>? stops,
  }) async {
    try {
      final body = <String, dynamic>{};
      final current = await getRouteById(routeId);
      body['id'] = int.tryParse(routeId) ?? 0;
      body['routeName'] = name ?? current?.name ?? '';
      body['schoolName'] = description ?? current?.schoolName ?? '';
      body['adminUserId'] = current?.schoolId ?? '';
      body['createdAt'] =
          current?.createdAt.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String();
      body['updatedAt'] = DateTime.now().toUtc().toIso8601String();

      final response = await _apiClient.put(
        Endpoints.updateRoute(routeId),
        body: body,
      );

      final route = response is Map
          ? BusRoute.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : BusRoute(
              id: routeId,
              name: body['routeName']?.toString() ?? '',
              schoolId: body['adminUserId']?.toString(),
              schoolName: body['schoolName']?.toString(),
              stops: current?.stops ?? [],
              createdAt: current?.createdAt ?? DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Update buffers
      await _buffer.saveBuffer(
        key: BufferKeys.routeDetails(routeId),
        data: route,
        expiration: const Duration(minutes: 20),
      );
      await _buffer.clearBuffer(BufferKeys.routes);
      await _buffer.clearBuffer('${BufferKeys.routes}_by_user');

      return route;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Delete a route
  /// DELETE /api/routes/delete/{id}
  Future<void> deleteRoute(String routeId) async {
    try {
      await _apiClient.delete(Endpoints.deleteRoute(routeId));

      // Clear related buffers
      await _buffer.clearBuffer(BufferKeys.routeDetails(routeId));
      await _buffer.clearCategory('routes');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Get routes by school ID or school name
  /// Filters routes by the school ID or school name to ensure school-scoped data
  Future<List<BusRoute>> getRoutesBySchool(
    String schoolId, {
    String? schoolName,
  }) async {
    return _buffer.withBuffer<List<BusRoute>>(
      apiCall: () async {
        // First try to get all routes and filter by school
        final response = await _apiClient.get(Endpoints.getAllRoutes);

        final routesData = ApiClient.unwrapList(response);

        // Filter routes by school ID or school name
        final routes = routesData
            .map((route) => BusRoute.fromJson(route))
            .where((route) {
              // Try to match by school ID first
              if (route.schoolId != null && route.schoolId!.isNotEmpty) {
                return route.schoolId == schoolId;
              }
              // Fallback to school name matching
              if (schoolName != null && route.schoolName != null) {
                return route.schoolName!.toLowerCase().contains(
                      schoolName.toLowerCase(),
                    ) ||
                    schoolName.toLowerCase().contains(
                      route.schoolName!.toLowerCase(),
                    );
              }
              return false;
            })
            .toList();

        return routes;
      },
      bufferKey: '${BufferKeys.routes}_school_$schoolId',
      fallbackData: <BusRoute>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Refresh routes cache in background
  Future<void> refreshRoutesCache() async {
    await _buffer.refreshBuffer<List<BusRoute>>(
      apiCall: () => getAllRoutes(),
      bufferKey: BufferKeys.routes,
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Clear all route-related buffers
  Future<void> clearRouteBuffers() async {
    await _buffer.clearCategory('routes');
  }
}
