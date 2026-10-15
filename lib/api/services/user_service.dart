import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';
import '../../services/token_storage.dart';

/// User Service - Handles user profile-related API calls with fallback buffers
class UserService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();
  final TokenStorage _tokenStorage = TokenStorage();

  /// Get user profile with buffer fallback
  /// GET /api/auth/get/account
  Future<UserProfile> getProfile() async {
    return _buffer.withBuffer<UserProfile>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.userProfile);
        final json = ApiClient.unwrapObject(response);
        return json == null ? UserProfile.empty() : UserProfile.fromJson(json);
      },
      bufferKey: 'users/profile',
      fallbackData: UserProfile.empty(),
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Update user profile (no buffer - fresh data required)
  /// No text-profile update endpoint is defined in api.md; this updates local
  /// cached profile data only.
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? licenseNumber,
    String? vehicleNumber,
  }) async {
    try {
      final currentProfile = await getProfile();
      final profile = UserProfile(
        id: currentProfile.id,
        name: name ?? currentProfile.name,
        phone: phone ?? currentProfile.phone,
        email: email ?? currentProfile.email,
        avatar: currentProfile.avatar,
        role: currentProfile.role,
        licenseNumber: licenseNumber ?? currentProfile.licenseNumber,
        vehicleNumber: vehicleNumber ?? currentProfile.vehicleNumber,
        schoolId: currentProfile.schoolId,
        schoolName: currentProfile.schoolName,
        vehicle: currentProfile.vehicle,
        stats: currentProfile.stats,
        createdAt: currentProfile.createdAt,
        updatedAt: DateTime.now(),
      );

      await _tokenStorage.saveUserData(
        userId: profile.id,
        name: profile.name,
        phone: profile.phone,
        role: profile.role,
        email: profile.email,
        avatar: profile.avatar,
        schoolId: profile.schoolId,
        schoolName: profile.schoolName,
      );

      // Update buffer with new profile
      await _buffer.saveBuffer(
        key: 'users/profile',
        data: profile,
        expiration: const Duration(minutes: 20),
      );

      return profile;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Change password (no buffer - always requires fresh API call)
  /// POST /api/auth/change/password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        Endpoints.changePassword,
        body: {
          'phoneNumber': await _requireStoredPhoneNumber(),
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Upload profile photo (no buffer - always requires fresh API call)
  /// POST /api/auth/update/profile/picture
  Future<String> uploadAvatar(String filePath) async {
    debugPrint('📤 UserService.uploadAvatar called');
    debugPrint('   File path: $filePath');

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _apiClient.post(
        Endpoints.updateProfilePicture,
        body: {'image': base64Image},
      );

      debugPrint('   Response received: $response');

      // Handle various response formats
      String? avatarUrl;

      // Case 1: Response is a direct string URL
      if (response is String && response.isNotEmpty) {
        avatarUrl = response;
        debugPrint('   Response is direct string URL: $avatarUrl');
      }
      // Case 2: Response is a map with data
      else if (response is Map) {
        final data = response['data'] ?? response;
        debugPrint('   Response data: $data');

        if (data is String && data.isNotEmpty) {
          avatarUrl = data;
          debugPrint('   Response data is string URL: $avatarUrl');
        } else if (data is Map) {
          // Try multiple possible field names for the image URL
          final possibleFields = [
            'imageUrl',
            'profileImage',
            'photo',
            'image_url',
            'url',
            'avatar',
            'avatar_url',
            'image',
            'picture',
            'profile_picture',
            'profileImageUrl',
            'avatarUrl',
          ];

          for (final field in possibleFields) {
            final value = data[field];
            if (value != null && value.toString().isNotEmpty) {
              avatarUrl = value.toString();
              debugPrint('   Found avatar URL in field "$field": $avatarUrl');
              break;
            }
          }
        }
      }

      // Never persist the raw base64 payload as the avatar URL. api.md's
      // update/profile/picture returns no image URL, so fall back to empty and
      // let the caller keep the existing avatar / refresh the profile.
      avatarUrl ??= '';

      // Clear profile buffer to force refresh
      await _buffer.clearBuffer('users/profile');
      debugPrint('   Upload completed successfully');

      return avatarUrl;
    } on ApiException catch (e) {
      debugPrint('   ApiException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('   Unexpected error: $e');
      throw ApiException(message: e.toString());
    }
  }

  /// Get notifications with buffer fallback
  /// GET /api/notifications/get/all
  Future<List<Notification>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
    VoidCallback? onFallback,
  }) async {
    return _buffer.withBuffer<List<Notification>>(
      onFallback: onFallback,
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getAllNotifications);

        final notificationsData = ApiClient.unwrapList(response);

        final notifications = notificationsData
            .map((n) => Notification.fromJson(n))
            .toList();

        return notifications;
      },
      bufferKey: unreadOnly
          ? '${BufferKeys.notifications}_unread'
          : '${BufferKeys.notifications}_page_$page',
      fallbackData: <Notification>[],
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get unread notifications count with buffer fallback
  Future<int> getUnreadNotificationsCount() async {
    return _buffer.withBuffer<int>(
      apiCall: () async {
        final notifications = await getNotifications(unreadOnly: true);
        return notifications.length;
      },
      bufferKey: BufferKeys.unreadNotificationsCount,
      fallbackData: 0,
      cacheDuration: const Duration(minutes: 5),
    );
  }

  /// Mark notification as read
  /// No notification read endpoint is defined in api.md.
  Future<void> markNotificationRead(String notificationId) async {
    try {
      // Clear notification buffers to force refresh
      await _buffer.clearCategory('notifications');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Mark all notifications as read
  /// No notification read-all endpoint is defined in api.md.
  Future<void> markAllNotificationsRead() async {
    try {
      // Clear notification buffers
      await _buffer.clearCategory('notifications');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Refresh notifications cache in background
  Future<void> refreshNotificationsCache() async {
    await _buffer.refreshBuffer<List<Notification>>(
      apiCall: () => getNotifications(),
      bufferKey: '${BufferKeys.notifications}_page_1',
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Clear all user-related buffers
  Future<void> clearUserBuffers() async {
    await _buffer.clearBuffer('users/profile');
    await _buffer.clearCategory('notifications');
  }

  Future<String> _requireStoredPhoneNumber() async {
    final phone = await _tokenStorage.getUserPhone();
    if (phone == null || phone.isEmpty) {
      throw ApiException(message: 'Phone number is required');
    }
    return phone;
  }
}

/// User Profile Model
class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final String role;
  final String? licenseNumber;
  final String? vehicleNumber;
  final String? schoolId;
  final String? schoolName;
  final Vehicle? vehicle;
  final Stats stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    required this.role,
    this.licenseNumber,
    this.vehicleNumber,
    this.schoolId,
    this.schoolName,
    this.vehicle,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['fullname'] ?? json['name'] ?? '',
      phone: json['phoneNumber'] ?? json['phone'] ?? '',
      email: json['email'],
      avatar: json['profileImage'] ?? json['avatar'],
      role: json['userType'] ?? json['role'] ?? 'unknown',
      licenseNumber:
          json['licenseImage'] ??
          json['license_number'] ??
          json['licenseNumber'],
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
      schoolId: json['school_id'] ?? json['schoolId'] ?? json['companyOrgId'],
      schoolName:
          json['schoolname'] ??
          json['school_name'] ??
          json['schoolName'] ??
          json['companyOrgName'],
      vehicle: json['vehicle'] != null
          ? Vehicle.fromJson(json['vehicle'])
          : null,
      stats: json['stats'] != null
          ? Stats.fromJson(json['stats'])
          : Stats.empty(),
      createdAt:
          _parseDateTime(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
      updatedAt:
          _parseDateTime(json['updated_at'] ?? json['updatedAt']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'role': role,
      'license_number': licenseNumber,
      'vehicle_number': vehicleNumber,
      'school_id': schoolId,
      'school_name': schoolName,
      'vehicle': vehicle?.toJson(),
      'stats': stats.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.empty() {
    return UserProfile(
      id: '',
      name: '',
      phone: '',
      role: 'unknown',
      stats: Stats.empty(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

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

/// Vehicle Model
class Vehicle {
  final String id;
  final String number;
  final String? model;
  final String? color;
  final int? capacity;

  Vehicle({
    required this.id,
    required this.number,
    this.model,
    this.color,
    this.capacity,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      number:
          json['number'] ??
          json['registrationNumber'] ??
          json['registration_number'] ??
          '',
      model: json['model'],
      color: json['color'],
      capacity: json['capacity'] is int
          ? json['capacity']
          : int.tryParse(json['capacity']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'model': model,
      'color': color,
      'capacity': capacity,
    };
  }
}

/// Stats Model
class Stats {
  final int totalTrips;
  final int completedTrips;
  final double totalDistance;
  final int totalStudents;
  final double rating;

  Stats({
    required this.totalTrips,
    required this.completedTrips,
    required this.totalDistance,
    required this.totalStudents,
    required this.rating,
  });

  factory Stats.empty() {
    return Stats(
      totalTrips: 0,
      completedTrips: 0,
      totalDistance: 0,
      totalStudents: 0,
      rating: 0,
    );
  }

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalTrips: json['total_trips'] ?? json['totalTrips'] ?? 0,
      completedTrips: json['completed_trips'] ?? json['completedTrips'] ?? 0,
      totalDistance:
          (json['total_distance'] ?? json['totalDistance'])?.toDouble() ?? 0,
      totalStudents: json['total_students'] ?? json['totalStudents'] ?? 0,
      rating: (json['rating'])?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_trips': totalTrips,
      'completed_trips': completedTrips,
      'total_distance': totalDistance,
      'total_students': totalStudents,
      'rating': rating,
    };
  }
}

/// Notification Model
class Notification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final String? tripId;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.tripId,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: json['type'],
      tripId: json['trip_id'] ?? json['tripId'],
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt:
          _parseDateTime(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'trip_id': tripId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

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
