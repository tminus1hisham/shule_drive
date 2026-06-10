import 'package:flutter/foundation.dart';

/// Bus / vehicle model.
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
      'id': int.tryParse(id) ?? 0,
      'numberPlate': registrationNumber,
      'seatingCapacity': int.tryParse(capacity ?? '') ?? 0,
      'companyOrgId': schoolId ?? '',
      'latitude': 0.0,
      'longitude': 0.0,
      'isBusActive': isActive,
      'isBusDeleted': false,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
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
