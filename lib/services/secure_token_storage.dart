import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Token Storage - Uses flutter_secure_storage for encrypted token storage
/// Suitable for production apps with sensitive authentication data
class SecureTokenStorage {
  static final SecureTokenStorage _instance = SecureTokenStorage._internal();
  factory SecureTokenStorage() => _instance;
  SecureTokenStorage._internal();

  // Secure storage instance with Android & iOS options
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accountName: 'shuledrive_secure_storage',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for storage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _userEmailKey = 'user_email';
  static const String _userAvatarKey = 'user_avatar';
  static const String _mqttSessionIdKey = 'mqtt_session_id';

  /// Save auth tokens securely
  Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
    String? mqttSessionId,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (mqttSessionId != null) {
      await _secureStorage.write(key: _mqttSessionIdKey, value: mqttSessionId);
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  /// Get MQTT session ID
  Future<String?> getMqttSessionId() async {
    return await _secureStorage.read(key: _mqttSessionIdKey);
  }

  /// Save user data securely
  Future<void> saveUserData({
    required String userId,
    required String name,
    required String phone,
    required String role,
    String? email,
    String? avatar,
  }) async {
    await _secureStorage.write(key: _userIdKey, value: userId);
    await _secureStorage.write(key: _userNameKey, value: name);
    await _secureStorage.write(key: _userPhoneKey, value: phone);
    await _secureStorage.write(key: _userRoleKey, value: role);
    if (email != null) {
      await _secureStorage.write(key: _userEmailKey, value: email);
    }
    if (avatar != null) {
      await _secureStorage.write(key: _userAvatarKey, value: avatar);
    }
  }

  /// Get user ID (async)
  Future<String?> getUserId() async {
    return await _secureStorage.read(key: _userIdKey);
  }
  
  // Note: flutter_secure_storage doesn't support sync reads
  // Use cached value or async method instead
  String? _cachedUserId;
  
  /// Cache user ID for sync access (call after login)
  void cacheUserId(String userId) {
    _cachedUserId = userId;
  }
  
  /// Get cached user ID (sync, may be null if not cached)
  String? getUserIdSync() => _cachedUserId;

  /// Get user name
  Future<String?> getUserName() async {
    return await _secureStorage.read(key: _userNameKey);
  }

  /// Get user phone
  Future<String?> getUserPhone() async {
    return await _secureStorage.read(key: _userPhoneKey);
  }

  /// Get user role
  Future<String?> getUserRole() async {
    return await _secureStorage.read(key: _userRoleKey);
  }

  /// Get user email
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: _userEmailKey);
  }

  /// Get user avatar
  Future<String?> getUserAvatar() async {
    return await _secureStorage.read(key: _userAvatarKey);
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    // Also clear cached data
    _cachedUserId = null;
  }

  /// Clear only tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _mqttSessionIdKey);
  }
}
