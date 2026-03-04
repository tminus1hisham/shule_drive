import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../services/token_storage.dart';
import '../../utils/buffer_manager.dart';

/// Auth Service - Handles authentication-related API calls with fallback buffers
class AuthService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();
  final BufferManager _buffer = BufferManager();

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
        body: {'PhoneNumber': normalizedPhone, 'Password': password},
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
        body: {'PhoneNumber': normalizedPhone, 'OTP': otp},
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
            schoolId: verifyResponse.user!.schoolId,
            schoolName: verifyResponse.user!.schoolName,
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
  /// Clears local auth token (no API endpoint exists on backend currently)
  Future<void> logout() async {
    try {
      // await _apiClient.post(Endpoints.logout); // Endpoint does not exist
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

  /// Get current user data from storage with buffer fallback
  Future<User?> getCurrentUser() async {
    // First try to get from buffer
    final bufferedUser = await _buffer.getBuffer<User>(
      key: BufferKeys.currentUser,
    );
    if (bufferedUser != null) {
      return bufferedUser;
    }

    // Fallback to stored user data
    final userId = await _tokenStorage.getUserId();
    if (userId == null) return null;

    final user = User(
      id: userId,
      name: await _tokenStorage.getUserName() ?? '',
      phone: await _tokenStorage.getUserPhone() ?? '',
      role: await _tokenStorage.getUserRole() ?? 'unknown',
      email: await _tokenStorage.getUserEmail(),
      avatar: await _tokenStorage.getUserAvatar(),
    );

    // Save to buffer for future use
    await _buffer.saveBuffer(
      key: BufferKeys.currentUser,
      data: user,
      expiration: const Duration(hours: 1),
    );

    return user;
  }

  /// Save current user to buffer
  Future<void> cacheCurrentUser(User user) async {
    await _buffer.saveBuffer(
      key: BufferKeys.currentUser,
      data: user,
      expiration: const Duration(hours: 1),
    );
  }

  /// Clear auth-related buffers
  Future<void> clearAuthBuffers() async {
    await _buffer.clearBuffer(BufferKeys.currentUser);
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

  /// Request password reset
  /// POST /api/auth/forgot/password
  /// Returns a resetToken in the response that must be passed to resetPassword
  Future<PasswordResetResponse> requestPasswordReset(String phoneNumber) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }

      final response = await _apiClient.post(
        Endpoints.forgotPassword,
        body: {'phoneNumber': normalizedPhone},
        requiresAuth: false,
      );

      if (kDebugMode) {
        print('📡 Forgot password response: $response');
      }

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
        body: {'PhoneNumber': normalizedPhone, 'OTP': otp},
        requiresAuth: false,
      );

      return PasswordResetResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Reset password with reset token
  /// POST /api/auth/reset/password
  /// Body: { "phoneNumber": "string", "newPassword": "string", "resetToken": "string" }
  Future<PasswordResetResponse> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }

      if (kDebugMode) {
        print('📡 Resetting password for: $normalizedPhone');
      }

      final response = await _apiClient.post(
        Endpoints.resetPassword,
        body: {
          'phoneNumber': normalizedPhone,
          'newPassword': newPassword,
          'resetToken': resetToken,
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

  /// Change password (for logged in users)
  /// POST /api/auth/change/password
  /// Requires: phoneNumber, currentPassword, newPassword
  Future<ChangePasswordResponse> changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Normalize phone number
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }

      final response = await _apiClient.post(
        Endpoints.changePassword,
        body: {
          'phoneNumber': normalizedPhone,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      return ChangePasswordResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Update profile picture
  /// POST /api/auth/update/profile/picture
  /// Returns the new image URL
  Future<String> updateProfilePicture({
    required String userId,
    required String imagePath,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Uploading profile picture:');
        print('  User ID: $userId');
        print('  Image Path: $imagePath');
        print('  Primary endpoint: ${Endpoints.uploadAvatar}');
        print('  Fallback endpoint: ${Endpoints.updateProfilePicture}');
      }

      // Read file as bytes and encode to base64
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (kDebugMode) {
        print('  File size: ${bytes.length} bytes');
        print('  Base64 length: ${base64Image.length}');
      }

      // Send as JSON payload (not multipart)
      // Try the user avatar endpoint first
      dynamic response;
      try {
        if (kDebugMode) {
          print('📤 Trying endpoint: ${Endpoints.uploadAvatar}');
          print('📤 UserId: $userId');
        }

        response = await _apiClient.post(
          Endpoints.uploadAvatar,
          body: {'userId': userId, 'image': base64Image},
        );
      } on ApiException catch (e) {
        // If uploadAvatar fails, try updateProfilePicture endpoint
        if (kDebugMode) {
          print('⚠️ uploadAvatar failed: ${e.message}');
          print(
            '📤 Falling back to endpoint: ${Endpoints.updateProfilePicture}',
          );
        }

        response = await _apiClient.post(
          Endpoints.updateProfilePicture,
          body: {'image': base64Image},
        );
      }

      if (kDebugMode) {
        print('📥 Upload response: $response');
      }

      // Handle various response formats
      String? imageUrl;

      // Case 1: Response is a direct string URL
      if (response is String && response.isNotEmpty) {
        imageUrl = response;
        if (kDebugMode) print('🖼️ Response is direct string URL');
      }
      // Case 2: Response is a map with data
      else if (response is Map) {
        final data = response['data'] ?? response;

        if (data is String && data.isNotEmpty) {
          imageUrl = data;
          if (kDebugMode) print('🖼️ Response data is string URL');
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
              imageUrl = value.toString();
              if (kDebugMode) {
                print('🖼️ Found image URL in field "$field": $imageUrl');
              }
              break;
            }
          }
        }
      }

      imageUrl ??= '';

      if (kDebugMode) {
        print('🖼️ Extracted image URL: $imageUrl');
      }

      if (imageUrl.isEmpty) {
        throw ApiException(
          message:
              'Failed to get image URL from response. Response: ${response.toString()}',
        );
      }

      return imageUrl.toString();
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Upload error: $e');
      }
      throw ApiException(message: e.toString());
    }
  }
}

/// Change Password Response Model
class ChangePasswordResponse {
  final bool success;
  final String? message;
  final List<String>? errors;

  ChangePasswordResponse({required this.success, this.message, this.errors});

  factory ChangePasswordResponse.fromJson(Map<String, dynamic> json) {
    // Check for success in multiple ways:
    // 1. Explicit success/isSuccess field
    // 2. Success message in response
    // 3. No errors present
    final message = json['message'] ?? json['msg'];
    final hasSuccessMessage =
        message != null && message.toString().toLowerCase().contains('success');
    final hasErrors =
        json['errors'] != null && (json['errors'] as List).isNotEmpty;

    return ChangePasswordResponse(
      success:
          json['success'] ??
          json['isSuccess'] ??
          hasSuccessMessage || !hasErrors,
      message: message,
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
    );
  }
}

/// Password Reset Response Model
class PasswordResetResponse {
  final bool success;
  final String? message;
  final String? resetToken;
  final List<String>? errors;

  PasswordResetResponse({
    required this.success,
    this.message,
    this.resetToken,
    this.errors,
  });

  factory PasswordResetResponse.fromJson(Map<String, dynamic> json) {
    // Handle various response formats - check if no errors = success
    final hasErrors =
        json['errors'] != null && (json['errors'] as List).isNotEmpty;
    final message = json['message'] ?? json['msg'];
    final hasSuccessMessage =
        message != null && message.toString().toLowerCase().contains('success');

    return PasswordResetResponse(
      success:
          json['success'] ??
          json['isSuccess'] ??
          hasSuccessMessage || !hasErrors,
      message: message,
      resetToken: json['resetToken'] ?? json['reset_token'] ?? json['token'],
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
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
        licenseNumber: json['licenseImage'] ?? json['license_number'],
        vehicleNumber: json['vehicleNumber'] ?? json['vehicle_number'],
        schoolId:
            json['school_id'] ??
            json['schoolId'] ??
            json['companyOrgId'] ??
            json['schoolID'],
        schoolName:
            json['school_name'] ??
            json['schoolName'] ??
            json['companyOrgName'] ??
            json['school'],
      );
      debugPrint(
        'Created user with role: ${user.role}, school: ${user.schoolId}',
      );
    }

    return LoginResponse(
      success:
          json['success'] ?? (user != null), // Success if we have user data
      message: json['message'],
      token: json['token'] ?? json['accessToken'],
      refreshToken: json['refreshToken'] ?? json['refresh_token'],
      user: user,
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
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
      final role =
          payloadJson['role'] ??
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

  RefreshTokenResponse({required this.success, this.token, this.refreshToken});

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
  final String? schoolId;
  final String? schoolName;

  User({
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
      schoolId:
          json['school_id'] ??
          json['schoolId'] ??
          json['companyOrgId'] ??
          json['schoolID'],
      schoolName:
          json['school_name'] ??
          json['schoolName'] ??
          json['companyOrgName'] ??
          json['school'],
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
      'school_id': schoolId,
      'school_name': schoolName,
    };
  }
}
