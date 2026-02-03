import 'package:shared_preferences/shared_preferences.dart';

/// Token Storage Service - Manages auth tokens using SharedPreferences
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  SharedPreferences? _prefs;
  
  // Keys for storage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _isLoggedInKey = 'is_logged_in';

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save auth tokens after login
  Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await init();
    await _prefs!.setString(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await _prefs!.setString(_refreshTokenKey, refreshToken);
    }
    await _prefs!.setBool(_isLoggedInKey, true);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    await init();
    return _prefs!.getString(_accessTokenKey);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    await init();
    return _prefs!.getString(_refreshTokenKey);
  }

  /// Save user data
  Future<void> saveUserData({
    required String userId,
    required String name,
    required String phone,
    required String role,
  }) async {
    await init();
    await _prefs!.setString(_userIdKey, userId);
    await _prefs!.setString(_userNameKey, name);
    await _prefs!.setString(_userPhoneKey, phone);
    await _prefs!.setString(_userRoleKey, role);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    await init();
    return _prefs!.getString(_userIdKey);
  }

  /// Get user name
  Future<String?> getUserName() async {
    await init();
    return _prefs!.getString(_userNameKey);
  }

  /// Get user phone
  Future<String?> getUserPhone() async {
    await init();
    return _prefs!.getString(_userPhoneKey);
  }

  /// Get user role
  Future<String?> getUserRole() async {
    await init();
    return _prefs!.getString(_userRoleKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    await init();
    return _prefs!.getBool(_isLoggedInKey) ?? false;
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await init();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_userNameKey);
    await _prefs!.remove(_userPhoneKey);
    await _prefs!.remove(_userRoleKey);
    await _prefs!.remove(_isLoggedInKey);
  }

  /// Clear only tokens (for token refresh scenarios)
  Future<void> clearTokens() async {
    await init();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.setBool(_isLoggedInKey, false);
  }
}
