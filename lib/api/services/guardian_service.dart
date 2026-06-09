import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';

/// Guardian Service - Handles guardian-related API calls
class GuardianService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();

  /// Get all guardians with optional companyOrgId filter
  /// GET /api/guardians/get/all?companyOrgId={id}
  Future<List<Guardian>> getAllGuardians({String? companyOrgId}) async {
    return _buffer.withBuffer<List<Guardian>>(
      apiCall: () async {
        final queryParams = <String, String>{};
        if (companyOrgId != null && companyOrgId.isNotEmpty) {
          queryParams['companyOrgId'] = companyOrgId;
        }

        final response = await _apiClient.get(
          Endpoints.getAllGuardians,
          queryParams: queryParams.isNotEmpty ? queryParams : null,
        );

        final guardiansData = ApiClient.unwrapList(response);

        final guardians = guardiansData
            .map((guardian) => Guardian.fromJson(guardian))
            .toList();

        return guardians;
      },
      bufferKey: '${BufferKeys.guardians()}_${companyOrgId ?? 'all'}',
      fallbackData: <Guardian>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Get guardians by school
  /// GET /api/guardians/get/by/school
  Future<List<Guardian>> getGuardiansBySchool(String schoolId) async {
    return _buffer.withBuffer<List<Guardian>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getGuardiansBySchool,
          queryParams: {'schoolId': schoolId},
        );

        final guardiansData = ApiClient.unwrapList(response);

        final guardians = guardiansData
            .map((guardian) => Guardian.fromJson(guardian))
            .toList();

        return guardians;
      },
      bufferKey: '${BufferKeys.guardians()}_school_$schoolId',
      fallbackData: <Guardian>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Get guardian by ID
  /// GET /api/guardians/get/{id}
  Future<Guardian?> getGuardianById(String id) async {
    try {
      final response = await _apiClient.get(Endpoints.getGuardianById(id));

      final guardianData = ApiClient.unwrapObject(response);
      if (guardianData != null) {
        return Guardian.fromJson(guardianData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching guardian by ID: $e');
      }
      return null;
    }
  }

  /// Clear guardian-related buffers
  Future<void> clearGuardianBuffers() async {
    await _buffer.clearCategory('guardians');
  }
}

/// Guardian Model
class Guardian {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneNumber;
  final String? companyOrgId;
  final String? schoolId;
  final String? schoolName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Guardian({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneNumber,
    this.companyOrgId,
    this.schoolId,
    this.schoolName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Guardian.fromJson(Map<String, dynamic> json) {
    return Guardian(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name'] ?? json['fullname'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? json['phoneNumber'],
      phoneNumber: json['phoneNumber'] ?? json['phone'],
      companyOrgId:
          json['companyOrgId'] ??
          json['company_org_id'] ??
          json['school_id'] ??
          json['schoolId'],
      schoolId: json['school_id'] ?? json['schoolId'],
      schoolName:
          json['schoolname'] ?? json['school_name'] ?? json['schoolName'],
      isActive:
          json['userActive'] ?? json['isActive'] ?? json['is_active'] ?? true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'phoneNumber': phoneNumber,
      'companyOrgId': companyOrgId,
      'school_id': schoolId,
      'school_name': schoolName,
      'userActive': isActive,
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  /// Get the best phone number to use
  String? get bestPhoneNumber => phoneNumber ?? phone;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }
}
