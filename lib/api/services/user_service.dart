import 'package:http/http.dart' as http;
import '../api_client.dart';
import '../api_constants.dart';
import '../api_exceptions.dart';
import '../../utils/buffer_manager.dart';

/// User Service - Handles user profile-related API calls with fallback buffers
class UserService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();
  
  /// Get user profile with buffer fallback
  /// GET /user/profile
  Future<UserProfile> getProfile() async {
    return _buffer.withBuffer<UserProfile>(
      apiCall: () async {
        final response = await _apiClient.get(ApiConstants.userProfile);
        return UserProfile.fromJson(response['data'] ?? response);
      },
      bufferKey: 'users/profile',
      fallbackData: UserProfile.empty(),
      cacheDuration: const Duration(minutes: 20),
    );
  }
  
  /// Update user profile (no buffer - fresh data required)
  /// PUT /user/profile
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? licenseNumber,
    String? vehicleNumber,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (licenseNumber != null) body['license_number'] = licenseNumber;
      if (vehicleNumber != null) body['vehicle_number'] = vehicleNumber;
      
      final response = await _apiClient.put(
        ApiConstants.updateProfile,
        body: body,
      );
      
      final profile = UserProfile.fromJson(response['data']);
      
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
  /// POST /user/change-password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.changePassword,
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Upload profile photo (no buffer - always requires fresh API call)
  /// POST /user/avatar
  Future<String> uploadAvatar(String filePath) async {
    try {
      final file = await http.MultipartFile.fromPath('avatar', filePath);
      
      final response = await _apiClient.postMultipart(
        '/user/avatar',
        fields: {},
        files: [file],
      );
      
      final avatarUrl = response['data']['avatar_url']?.toString() ?? '';
      
      // Clear profile buffer to force refresh
      await _buffer.clearBuffer('users/profile');
      
      return avatarUrl;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get notifications with buffer fallback
  /// GET /notifications
  Future<List<Notification>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    return _buffer.withBuffer<List<Notification>>(
      apiCall: () async {
        final response = await _apiClient.get(
          ApiConstants.notifications,
          queryParams: {
            'page': page.toString(),
            'limit': limit.toString(),
            if (unreadOnly) 'unread_only': 'true',
          },
        );
        
        final notifications = (response['data'] as List? ?? [])
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
        final response = await _apiClient.get(
          ApiConstants.notifications,
          queryParams: {'unread_only': 'true', 'count_only': 'true'},
        );
        return response['data']?['count'] ?? 0;
      },
      bufferKey: BufferKeys.unreadNotificationsCount,
      fallbackData: 0,
      cacheDuration: const Duration(minutes: 5),
    );
  }
  
  /// Mark notification as read
  /// PATCH /notifications/{id}/read
  Future<void> markNotificationRead(String notificationId) async {
    try {
      final endpoint = ApiConstants.markNotificationRead
          .replaceAll('{id}', notificationId);
      await _apiClient.patch(endpoint);
      
      // Clear notification buffers to force refresh
      await _buffer.clearCategory('notifications');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Mark all notifications as read
  /// PATCH /notifications/read-all
  Future<void> markAllNotificationsRead() async {
    try {
      await _apiClient.patch('/notifications/read-all');
      
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
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
      role: json['role'] ?? 'unknown',
      licenseNumber: json['license_number'] ?? json['licenseNumber'],
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
      schoolId: json['school_id'] ?? json['schoolId'] ?? json['companyOrgId'],
      schoolName: json['school_name'] ?? json['schoolName'] ?? json['companyOrgName'],
      vehicle: json['vehicle'] != null 
          ? Vehicle.fromJson(json['vehicle']) 
          : null,
      stats: json['stats'] != null 
          ? Stats.fromJson(json['stats']) 
          : Stats.empty(),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
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
      number: json['number'] ?? json['registrationNumber'] ?? json['registration_number'] ?? '',
      model: json['model'],
      color: json['color'],
      capacity: json['capacity'] is int ? json['capacity'] : int.tryParse(json['capacity']?.toString() ?? ''),
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
      totalDistance: (json['total_distance'] ?? json['totalDistance'])?.toDouble() ?? 0,
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
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
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
