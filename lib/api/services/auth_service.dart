import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../services/token_storage.dart';

/// Auth Service - Handles authentication-related API calls
class AuthService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();
  
  /// Login with phone number and password
  /// POST /api/auth/login
  Future<LoginResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // Normalize phone number - remove '+' prefix if present
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      
      final response = await _apiClient.post(
        Endpoints.login,
        body: {
          'PhoneNumber': normalizedPhone,
          'Password': password,
        },
        requiresAuth: false,
      );
      
      return LoginResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Verify OTP
  /// POST /api/auth/verify-otp
  Future<VerifyOtpResponse> verifyOtp(String phoneNumber, String otp) async {
    try {
      // Use same normalization as login
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      // Try local format if E.164 doesn't work
      if (normalizedPhone.startsWith('254') && normalizedPhone.length == 12) {
        normalizedPhone = '0${normalizedPhone.substring(3)}';
      }
      
      final response = await _apiClient.post(
        Endpoints.verifyOtp,
        body: {
          'PhoneNumber': normalizedPhone,
          'OTP': otp,
        },
        requiresAuth: false,
      );
      
      final verifyResponse = VerifyOtpResponse.fromJson(response);
      
      // Save auth tokens and user data
      if (verifyResponse.token != null) {
        await _apiClient.saveTokens(
          accessToken: verifyResponse.token!,
          refreshToken: verifyResponse.refreshToken,
        );
        
        // Save user data
        if (verifyResponse.user != null) {
          await _tokenStorage.saveUserData(
            userId: verifyResponse.user!.id,
            name: verifyResponse.user!.name,
            phone: verifyResponse.user!.phone,
            role: verifyResponse.user!.role,
          );
        }
      }
      
      return verifyResponse;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Refresh access token
  /// POST /api/auth/refresh/token
  Future<RefreshTokenResponse> refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      
      if (refreshToken == null) {
        throw UnauthorizedException(message: 'No refresh token available');
      }
      
      final response = await _apiClient.post(
        Endpoints.refreshToken,
        body: {'refresh_token': refreshToken},
        requiresAuth: false,
      );
      
      final refreshResponse = RefreshTokenResponse.fromJson(response);
      
      // Update auth tokens
      if (refreshResponse.token != null) {
        await _apiClient.saveTokens(
          accessToken: refreshResponse.token!,
          refreshToken: refreshResponse.refreshToken,
        );
      }
      
      return refreshResponse;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Logout
  /// POST /api/auth/logout
  Future<void> logout() async {
    try {
      await _apiClient.post(Endpoints.logout);
      await _apiClient.clearAuthToken();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _apiClient.isAuthenticated();
  }
  
  /// Get current user data from storage
  Future<User?> getCurrentUser() async {
    final userId = await _tokenStorage.getUserId();
    if (userId == null) return null;
    
    return User(
      id: userId,
      name: await _tokenStorage.getUserName() ?? '',
      phone: await _tokenStorage.getUserPhone() ?? '',
      role: await _tokenStorage.getUserRole() ?? 'attendant',
    );
  }
  
  /// Update user profile
  /// PUT /api/user/profile
  Future<User> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final response = await _apiClient.put(
        '${Endpoints.updateProfile}/$userId',
        body: {
          if (name != null) 'Name': name,
          if (phone != null) 'PhoneNumber': phone,
          if (email != null) 'Email': email,
        },
      );
      
      return User.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Request password reset OTP
  /// POST /api/auth/forgot-password
  Future<PasswordResetResponse> requestPasswordReset(String phoneNumber) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      
      final response = await _apiClient.post(
        Endpoints.forgotPassword,
        body: {
          'PhoneNumber': normalizedPhone,
        },
        requiresAuth: false,
      );
      
      return PasswordResetResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Verify password reset OTP
  /// POST /api/auth/verify-reset-otp
  Future<PasswordResetResponse> verifyPasswordResetOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      
      final response = await _apiClient.post(
        Endpoints.verifyResetOtp,
        body: {
          'PhoneNumber': normalizedPhone,
          'OTP': otp,
        },
        requiresAuth: false,
      );
      
      return PasswordResetResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Reset password with OTP
  /// POST /api/auth/reset-password
  Future<PasswordResetResponse> resetPassword({
    required String phoneNumber,
    required String otp,
    required String newPassword,
  }) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      
      final response = await _apiClient.post(
        Endpoints.resetPassword,
        body: {
          'PhoneNumber': normalizedPhone,
          'OTP': otp,
          'NewPassword': newPassword,
        },
        requiresAuth: false,
      );
      
      return PasswordResetResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
}

/// Password Reset Response Model
class PasswordResetResponse {
  final bool success;
  final String? message;
  final List<String>? errors;
  
  PasswordResetResponse({
    required this.success,
    this.message,
    this.errors,
  });
  
  factory PasswordResetResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetResponse(
      success: json['success'] ?? false,
      message: json['message'],
      errors: json['errors'] != null 
          ? List<String>.from(json['errors']) 
          : null,
    );
  }
}

/// Login Response Model
class LoginResponse {
  final bool success;
  final String? message;
  final String? token;
  final String? refreshToken;
  final User? user;
  final List<String>? errors;
  
  LoginResponse({
    required this.success,
    this.message,
    this.token,
    this.refreshToken,
    this.user,
    this.errors,
  });
  
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Debug: print the raw response to understand structure
    debugPrint('LoginResponse raw: $json');
    
    User? user;
    
    // Try to extract user data from various API response formats
    // Priority: 1. userType from body, 2. role from body, 3. role from JWT token
    
    String? extractedRole;
    String? extractedName;
    String? extractedId;
    String? extractedPhone;
    String? extractedEmail;
    
    // Try to get from response body first
    if (json['userType'] != null) {
      extractedRole = json['userType'];
      debugPrint('Found userType in response body: $extractedRole');
    } else if (json['role'] != null) {
      extractedRole = json['role'];
      debugPrint('Found role in response body: $extractedRole');
    }
    
    // Get other user fields from body
    extractedName = json['fullname'] ?? json['userName'] ?? json['name'];
    extractedId = json['userId']?.toString() ?? json['id']?.toString();
    extractedPhone = json['phoneNumber'] ?? json['phone'];
    extractedEmail = json['email'];
    
    // If no role in body, try JWT token
    if (extractedRole == null && json['token'] != null) {
      extractedRole = _extractRoleFromToken(json['token']);
      debugPrint('Extracted role from JWT: $extractedRole');
    }
    
    // If we have a token but no ID, try to get ID from JWT
    if (extractedId == null && json['token'] != null) {
      extractedId = _extractUserIdFromToken(json['token']);
    }
    
    // Create user if we have minimum data
    if (extractedRole != null || json['token'] != null) {
      user = User(
        id: extractedId ?? '',
        name: User._cleanName(extractedName ?? ''),
        phone: extractedPhone ?? '',
        email: extractedEmail,
        avatar: json['profileImage'] ?? json['avatar'],
        role: extractedRole ?? 'unknown',
      );
      debugPrint('Created user with role: ${user.role}');
    }
    
    return LoginResponse(
      success: json['success'] ?? (user != null), // Success if we have user data
      message: json['message'],
      token: json['token'] ?? json['accessToken'],
      refreshToken: json['refreshToken'] ?? json['refresh_token'],
      user: user,
      errors: json['errors'] != null 
          ? List<String>.from(json['errors']) 
          : null,
    );
  }
  
  /// Extract role from JWT token payload
  static String? _extractRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      // Base64 decode the payload (middle part)
      String payload = parts[1];
      
      // Fix base64url encoding: replace - with + and _ with /
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      
      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      // Use base64 decode instead of base64Url since we already converted
      final decoded = utf8.decode(base64.decode(payload));
      final payloadJson = jsonDecode(decoded);
      
      debugPrint('JWT payload decoded: $payloadJson');
      
      // Try different possible role fields in JWT
      final role = payloadJson['role'] ?? 
                   payloadJson['userType'] ?? 
                   payloadJson['Role'] ?? 
                   payloadJson['UserType'];
      
      debugPrint('Extracted role from JWT: $role');
      return role;
    } catch (e, stackTrace) {
      debugPrint('Token decode error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Extract user ID from JWT token payload
  static String? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      String payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      final decoded = utf8.decode(base64.decode(payload));
      final payloadJson = jsonDecode(decoded);
      
      // Try different possible ID fields
      return payloadJson['UserId'] ?? 
             payloadJson['userId'] ?? 
             payloadJson['sub'] ??
             payloadJson['id'];
    } catch (e) {
      debugPrint('UserId extraction error: $e');
      return null;
    }
  }
}

/// Verify OTP Response Model
class VerifyOtpResponse {
  final bool success;
  final String message;
  final String? token;
  final String? refreshToken;
  final User? user;
  
  VerifyOtpResponse({
    required this.success,
    required this.message,
    this.token,
    this.refreshToken,
    this.user,
  });
  
  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'],
      refreshToken: json['refresh_token'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

/// Refresh Token Response Model
class RefreshTokenResponse {
  final bool success;
  final String? token;
  final String? refreshToken;
  
  RefreshTokenResponse({
    required this.success,
    this.token,
    this.refreshToken,
  });
  
  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      success: json['success'] ?? false,
      token: json['token'],
      refreshToken: json['refresh_token'],
    );
  }
}

/// User Model
class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final String role;
  final String? licenseNumber;
  final String? vehicleNumber;
  
  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    required this.role,
    this.licenseNumber,
    this.vehicleNumber,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    // Support both API formats:
    // - Guardian/Driver API: fullname, userId, phoneNumber, userType, profileImage
    // - Standard API: name, id, phone, role, avatar
    final name = json['fullname'] ?? json['name'] ?? '';
    final id = json['userId']?.toString() ?? json['id']?.toString() ?? '';
    final phone = json['phoneNumber'] ?? json['phone'] ?? '';
    final role = json['userType'] ?? json['role'] ?? 'attendant';
    final avatar = json['profileImage'] ?? json['avatar'];
    
    return User(
      id: id,
      name: _cleanName(name),
      phone: phone,
      email: json['email'],
      avatar: avatar,
      role: role,
      licenseNumber: json['licenseImage'] ?? json['license_number'],
      vehicleNumber: json['vehicleNumber'] ?? json['vehicle_number'],
    );
  }
  
  /// Clean up name - extract only first and last name
  /// e.g., "ObedMunyao-34016552457676507777686405413468" -> "Obed Munyao"
  static String _cleanName(String rawName) {
    if (rawName.isEmpty) return '';
    
    // Remove any trailing IDs after hyphen (e.g., "-34016552457676507777686405413468")
    String cleaned = rawName.split('-').first.trim();
    
    // Try to split camelCase into separate words
    // e.g., "ObedMunyao" -> "Obed Munyao"
    final camelCasePattern = RegExp(r'([a-z])([A-Z])');
    cleaned = cleaned.replaceAllMapped(camelCasePattern, (match) {
      return '${match.group(1)} ${match.group(2)}';
    });
    
    // Clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Extract only first and last name (if more than 2 words)
    final parts = cleaned.split(' ');
    if (parts.length > 2) {
      return '${parts.first} ${parts.last}';
    }
    
    return cleaned;
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
    };
  }
}
