import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_token_storage.dart';

/// Cross-platform Token Storage
/// Uses flutter_secure_storage for mobile (encrypted)
/// Uses shared_preferences for web (local storage)
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  // Mobile secure storage
  final SecureTokenStorage _secureStorage = SecureTokenStorage();

  // Web shared preferences
  SharedPreferences? _prefs;
  final bool _isWeb = kIsWeb;

  // Keys for storage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _userEmailKey = 'user_email';
  static const String _userAvatarKey = 'user_avatar';
  static const String _userSchoolIdKey = 'user_school_id';
  static const String _userSchoolNameKey = 'user_school_name';
  static const String _needsPasswordChangeKey = 'needs_password_change';

  /// Initialize storage (call this before using other methods)
  Future<void> init() async {
    if (_isWeb) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  /// Check if running on web
  bool get isWeb => _isWeb;

  /// Save auth tokens
  Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    if (_isWeb) {
      await _prefs?.setString(_accessTokenKey, accessToken);
      if (refreshToken != null) {
        await _prefs?.setString(_refreshTokenKey, refreshToken);
      }
    } else {
      await _secureStorage.saveAuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    if (_isWeb) {
      return _prefs?.getString(_accessTokenKey);
    } else {
      return await _secureStorage.getAccessToken();
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    if (_isWeb) {
      return _prefs?.getString(_refreshTokenKey);
    } else {
      return await _secureStorage.getRefreshToken();
    }
  }

  /// Save user data
  Future<void> saveUserData({
    required String userId,
    required String name,
    required String phone,
    required String role,
    String? email,
    String? avatar,
    String? schoolId,
    String? schoolName,
  }) async {
    if (_isWeb) {
      await _prefs?.setString(_userIdKey, userId);
      await _prefs?.setString(_userNameKey, name);
      await _prefs?.setString(_userPhoneKey, phone);
      await _prefs?.setString(_userRoleKey, role);
      if (email != null) {
        await _prefs?.setString(_userEmailKey, email);
      }
      if (avatar != null) {
        await _prefs?.setString(_userAvatarKey, avatar);
      }
      if (schoolId != null) {
        await _prefs?.setString(_userSchoolIdKey, schoolId);
      }
      if (schoolName != null) {
        await _prefs?.setString(_userSchoolNameKey, schoolName);
      }
    } else {
      await _secureStorage.saveUserData(
        userId: userId,
        name: name,
        phone: phone,
        role: role,
        email: email,
        avatar: avatar,
        schoolId: schoolId,
        schoolName: schoolName,
      );
    }
  }

  /// Get user ID
  Future<String?> getUserId() async {
    if (_isWeb) {
      return _prefs?.getString(_userIdKey);
    } else {
      return await _secureStorage.getUserId();
    }
  }

  /// Get user name
  Future<String?> getUserName() async {
    if (_isWeb) {
      return _prefs?.getString(_userNameKey);
    } else {
      return await _secureStorage.getUserName();
    }
  }

  /// Get user phone
  Future<String?> getUserPhone() async {
    if (_isWeb) {
      return _prefs?.getString(_userPhoneKey);
    } else {
      return await _secureStorage.getUserPhone();
    }
  }

  /// Get user role
  Future<String?> getUserRole() async {
    if (_isWeb) {
      return _prefs?.getString(_userRoleKey);
    } else {
      return await _secureStorage.getUserRole();
    }
  }

  /// Get user email
  Future<String?> getUserEmail() async {
    if (_isWeb) {
      return _prefs?.getString(_userEmailKey);
    } else {
      return await _secureStorage.getUserEmail();
    }
  }

  /// Get user avatar
  Future<String?> getUserAvatar() async {
    if (_isWeb) {
      return _prefs?.getString(_userAvatarKey);
    } else {
      return await _secureStorage.getUserAvatar();
    }
  }

  /// Get user school ID
  Future<String?> getUserSchoolId() async {
    if (_isWeb) {
      return _prefs?.getString(_userSchoolIdKey);
    } else {
      return await _secureStorage.getUserSchoolId();
    }
  }

  /// Get user school name
  Future<String?> getUserSchoolName() async {
    if (_isWeb) {
      return _prefs?.getString(_userSchoolNameKey);
    } else {
      return await _secureStorage.getUserSchoolName();
    }
  }

  /// Get all user data as a map (for fast cached access)
  Future<Map<String, String>?> getUserData() async {
    final userId = await getUserId();
    if (userId == null) return null;

    return {
      'userId': userId,
      'name': await getUserName() ?? '',
      'phone': await getUserPhone() ?? '',
      'role': await getUserRole() ?? 'unknown',
      'email': await getUserEmail() ?? '',
      'avatar': await getUserAvatar() ?? '',
      'schoolId': await getUserSchoolId() ?? '',
      'schoolName': await getUserSchoolName() ?? '',
    };
  }

  /// Check if user is logged in (has access token)
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    if (_isWeb) {
      await _prefs?.clear();
    } else {
      await _secureStorage.clearAll();
    }
  }

  /// Clear only tokens
  Future<void> clearTokens() async {
    if (_isWeb) {
      await _prefs?.remove(_accessTokenKey);
      await _prefs?.remove(_refreshTokenKey);
    } else {
      await _secureStorage.clearTokens();
    }
  }

  /// Check if user needs to change password (first-time login)
  Future<bool> getNeedsPasswordChange() async {
    if (_isWeb) {
      return _prefs?.getBool(_needsPasswordChangeKey) ?? false;
    } else {
      return await _secureStorage.getNeedsPasswordChange();
    }
  }

  /// Set whether user needs to change password
  Future<void> setNeedsPasswordChange(bool value) async {
    if (_isWeb) {
      await _prefs?.setBool(_needsPasswordChangeKey, value);
    } else {
      await _secureStorage.setNeedsPasswordChange(value);
    }
  }

  /// Clear the password change requirement (called after password change)
  Future<void> clearNeedsPasswordChange() async {
    if (_isWeb) {
      await _prefs?.remove(_needsPasswordChangeKey);
    } else {
      await _secureStorage.clearNeedsPasswordChange();
    }
  }
}
