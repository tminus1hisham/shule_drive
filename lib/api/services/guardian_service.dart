import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../endpoints.dart';
import '../../models/guardian.dart';
import '../../utils/buffer_manager.dart';

// Re-export so existing `guardian_service.Guardian` consumers keep working.
export '../../models/guardian.dart';

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
