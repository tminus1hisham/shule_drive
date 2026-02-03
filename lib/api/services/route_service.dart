import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';

/// Route Service - Handles route-related API calls
class RouteService {
  final ApiClient _apiClient = ApiClient();
  
  /// Get all routes
  /// GET /api/routes/get/all
  Future<List<BusRoute>> getAllRoutes() async {
    try {
      final response = await _apiClient.get(Endpoints.getAllRoutes);
      
      final routes = (response['data'] as List)
          .map((route) => BusRoute.fromJson(route))
          .toList();
      
      return routes;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get routes by user
  /// GET /api/routes/get/by/user
  Future<List<BusRoute>> getRoutesByUser() async {
    try {
      final response = await _apiClient.get(Endpoints.getRoutesByUser);
      
      final routes = (response['data'] as List)
          .map((route) => BusRoute.fromJson(route))
          .toList();
      
      return routes;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
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
      
      return BusRoute.fromJson(response['data']);
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
      
      return BusRoute.fromJson(response['data']);
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      schoolId: json['school_id'],
      schoolName: json['school_name'],
      stops: (json['stops'] as List?)
          ?.map((s) => RouteStop.fromJson(s))
          .toList() ?? [],
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      order: json['order'] ?? 0,
      estimatedTime: json['estimated_time'],
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
