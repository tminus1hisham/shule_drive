import 'package:http/http.dart' as http;
import '../api_client.dart';
import '../api_constants.dart';
import '../api_exceptions.dart';

/// User Service - Handles user profile-related API calls
class UserService {
  final ApiClient _apiClient = ApiClient();
  
  /// Get user profile
  /// GET /user/profile
  Future<UserProfile> getProfile() async {
    try {
      final response = await _apiClient.get(ApiConstants.userProfile);
      
      return UserProfile.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Update user profile
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
      
      return UserProfile.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Change password
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
  
  /// Upload profile photo
  /// POST /user/avatar
  Future<String> uploadAvatar(String filePath) async {
    try {
      final file = await http.MultipartFile.fromPath('avatar', filePath);
      
      final response = await _apiClient.postMultipart(
        '/user/avatar',
        fields: {},
        files: [file],
      );
      
      return response['data']['avatar_url'];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get notifications
  /// GET /notifications
  Future<List<Notification>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.notifications,
        queryParams: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (unreadOnly) 'unread_only': 'true',
        },
      );
      
      final notifications = (response['data'] as List)
          .map((n) => Notification.fromJson(n))
          .toList();
      
      return notifications;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Mark notification as read
  /// PATCH /notifications/{id}/read
  Future<void> markNotificationRead(String notificationId) async {
    try {
      final endpoint = ApiConstants.markNotificationRead
          .replaceAll('{id}', notificationId);
      await _apiClient.patch(endpoint);
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
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
    this.vehicle,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
      role: json['role'] ?? 'attendant',
      licenseNumber: json['license_number'],
      vehicleNumber: json['vehicle_number'],
      vehicle: json['vehicle'] != null 
          ? Vehicle.fromJson(json['vehicle']) 
          : null,
      stats: json['stats'] != null 
          ? Stats.fromJson(json['stats']) 
          : Stats.empty(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
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
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      model: json['model'],
      color: json['color'],
      capacity: json['capacity'],
    );
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
      totalTrips: json['total_trips'] ?? 0,
      completedTrips: json['completed_trips'] ?? 0,
      totalDistance: json['total_distance']?.toDouble() ?? 0,
      totalStudents: json['total_students'] ?? 0,
      rating: json['rating']?.toDouble() ?? 0,
    );
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
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'],
      tripId: json['trip_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
