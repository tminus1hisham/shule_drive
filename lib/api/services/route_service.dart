import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';

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

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> routesData;
        if (response is List) {
          routesData = response;
        } else if (response is Map && response['data'] != null) {
          routesData = response['data'] as List;
        } else {
          routesData = [];
        }

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

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> routesData;
        if (response is List) {
          routesData = response;
        } else if (response is Map && response['data'] != null) {
          routesData = response['data'] as List;
        } else {
          routesData = [];
        }

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
        // Using endpoints helper - assuming there's a get route by id endpoint
        final response = await _apiClient.get('/api/routes/get/$routeId');
        return BusRoute.fromJson(response['data'] ?? response);
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
      final response = await _apiClient.post(
        Endpoints.createRoute,
        body: {
          'name': name,
          'description': description,
          'stops': stops.map((s) => s.toJson()).toList(),
          if (schoolId != null) 'school_id': schoolId,
        },
      );

      final route = BusRoute.fromJson(response['data']);

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
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (stops != null) body['stops'] = stops.map((s) => s.toJson()).toList();

      final response = await _apiClient.put(
        Endpoints.updateRoute(routeId),
        body: body,
      );

      final route = BusRoute.fromJson(response['data']);

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

/// Bus Route Model
class BusRoute {
  final String id;
  final String name;
  final String? description;
  final String? schoolId;
  final String? schoolName;
  final List<RouteStop> stops;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BusRoute({
    required this.id,
    required this.name,
    this.description,
    this.schoolId,
    this.schoolName,
    required this.stops,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id']?.toString() ?? '',
      name: json['routeName'] ?? json['name'] ?? '',
      description: json['description'],
      schoolId: json['school_id'] ?? json['schoolId'],
      schoolName: json['schoolName'] ?? json['school_name'],
      stops:
          (json['stops'] as List?)
              ?.map((s) => RouteStop.fromJson(s))
              .toList() ??
          [],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt:
          _parseDateTime(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'school_id': schoolId,
      'school_name': schoolName,
      'stops': stops.map((s) => s.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  int get stopCount => stops.length;

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

/// Route Stop Model
class RouteStop {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int order;
  final String? estimatedTime;

  RouteStop({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    required this.order,
    this.estimatedTime,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      order: json['order'] ?? 0,
      estimatedTime: json['estimated_time'] ?? json['estimatedTime'],
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
      'estimated_time': estimatedTime,
    };
  }
}
