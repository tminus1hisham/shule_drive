import 'package:flutter/foundation.dart';

/// Bus route model.
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
      // Use adminUserId as schoolId since that's how the API returns it
      schoolId:
          json['school_id'] ??
          json['schoolId'] ??
          json['adminUserId'] ??
          json['school']?['id']?.toString(),
      schoolName:
          json['schoolName'] ?? json['school_name'] ?? json['school']?['name'],
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

/// Route stop model.
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
