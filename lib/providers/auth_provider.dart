import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/api.dart' as api;
import '../api/services/auth_service.dart';
import '../api/services/user_service.dart';
import '../services/token_storage.dart';

/// User Roles
enum UserRole {
  driver,
  guardian,
  unknown;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return UserRole.driver;
      case 'guardian':
        return UserRole.guardian;
      default:
        return UserRole.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.driver:
        return 'Driver';
      case UserRole.guardian:
        return 'Guardian';
      case UserRole.unknown:
        return 'Unknown';
    }
  }
}

/// Auth Provider - Manages authentication state and role-based access
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TokenStorage _tokenStorage = TokenStorage();

  // Auth state
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // User data
  api.User? _currentUser;
  api.User? get currentUser => _currentUser;

  UserRole _userRole = UserRole.unknown;
  UserRole get userRole => _userRole;

  bool get isDriver => _userRole == UserRole.driver;
  bool get isGuardian => _userRole == UserRole.guardian;

  // Getters for user info
  String? get userId => _currentUser?.id;
  String? get userName => _currentUser?.name;
  String? get userPhone => _currentUser?.phone;
  String? get userAvatar => _currentUser?.avatar;
  String? get userEmail => _currentUser?.email;
  String? get userRoleName => _currentUser?.role;

  /// Get user data as Map for UI compatibility
  Map<String, dynamic> get userData => {
    'id': _currentUser?.id ?? '',
    'name': _currentUser?.name ?? 'Guest',
    'phone': _currentUser?.phone ?? '',
    'email': _currentUser?.email ?? '',
    'avatar':
        _currentUser?.avatar ??
        'https://ui-avatars.com/api/?name=${_currentUser?.name ?? "User"}&background=random',
    'role': _currentUser?.role ?? 'unknown',
    'licenseNumber': _currentUser?.licenseNumber,
    'vehicleNumber': _currentUser?.vehicleNumber,
  };

  /// Initialize auth state (call on app startup) - Optimized for speed
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Fast check - just verify token exists locally (no API call)
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        _isAuthenticated = false;
        return;
      }

      // Load cached user data immediately (fast)
      final cachedUser = await _tokenStorage.getUserData();
      if (cachedUser != null) {
        _currentUser = api.User(
          id: cachedUser['userId'] ?? '',
          name: cachedUser['name'] ?? '',
          phone: cachedUser['phone'] ?? '',
          role: cachedUser['role'] ?? 'unknown',
          email: cachedUser['email'],
          avatar: cachedUser['avatar'],
        );
        _userRole = UserRole.fromString(cachedUser['role'] ?? 'unknown');
        _isAuthenticated = true;
        notifyListeners(); // Show UI immediately with cached data
      }

      // Validate token and fetch fresh user data in background (non-blocking)
      // This updates the UI with fresh data when ready
      _refreshUserDataInBackground();
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Refresh user data in background without blocking UI
  Future<void> _refreshUserDataInBackground() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Only update if different from cached data
        if (_currentUser?.id != user.id ||
            _currentUser?.name != user.name ||
            _currentUser?.role != user.role) {
          _currentUser = user;
          _userRole = UserRole.fromString(user.role);
          notifyListeners();
        }
      } else {
        // Token invalid, logout
        _isAuthenticated = false;
        _currentUser = null;
        notifyListeners();
      }
    } catch (e) {
      // Silent fail - user sees cached data, will retry next time
      if (kDebugMode) print('⚠️ Background user refresh failed: $e');
    }
  }

  /// Login with phone number and password
  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      if (response.success && response.token != null) {
        // Save auth tokens
        await api.ApiClient().saveTokens(
          accessToken: response.token!,
          refreshToken: response.refreshToken,
        );

        // Save user data
        if (response.user != null) {
          await _tokenStorage.saveUserData(
            userId: response.user!.id,
            name: response.user!.name,
            phone: response.user!.phone,
            role: response.user!.role,
            email: response.user!.email,
            avatar: response.user!.avatar,
          );
        }

        // User authenticated successfully
        _currentUser = response.user;
        _userRole = UserRole.fromString(response.user?.role ?? 'unknown');
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        _setError(
          response.errors?.join(', ') ?? response.message ?? 'Login failed',
        );
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Login failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.verifyOtp(phoneNumber, otp);
      if (response.success && response.user != null) {
        _currentUser = response.user;
        _userRole = UserRole.fromString(response.user!.role);
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Verification failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final response = await _authService.refreshToken();
      return response.success;
    } on api.UnauthorizedException {
      // Token refresh failed, logout user
      await logout();
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Logout user
  /// Clears all tokens from memory and storage (works offline - no API call)
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Try server logout if available (don't wait for it)
      _authService.logout().catchError((_) {
        // Ignore server errors - we still want to logout locally
      });
    } catch (e) {
      // Ignore errors - proceed with local logout
    }

    // Clear all auth data - IMPORTANT: Order matters!

    // 1. Clear from ApiClient first (in-memory) - prevents new API requests
    api.ApiClient().forceClearToken();
    await api.ApiClient().clearAuthToken();

    // 2. Clear from TokenStorage (persistent storage)
    await _tokenStorage.clearAll();

    // 3. Reset all local state
    _currentUser = null;
    _userRole = UserRole.unknown;
    _isAuthenticated = false;
    _errorMessage = null;

    _setLoading(false);
    notifyListeners();
  }

  /// Update user profile via API and locally
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? email,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final updatedUser = await _authService.updateProfile(
        userId: _currentUser!.id,
        name: name,
        phone: phone,
        email: email,
      );

      _currentUser = updatedUser;

      // Update in storage
      await _tokenStorage.saveUserData(
        userId: updatedUser.id,
        name: updatedUser.name,
        phone: updatedUser.phone,
        role: updatedUser.role,
        email: updatedUser.email,
        avatar: updatedUser.avatar,
      );

      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update profile. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Request password reset OTP
  Future<bool> requestPasswordReset(String phoneNumber) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.requestPasswordReset(phoneNumber);
      if (response.success) {
        return true;
      } else {
        _setError(
          response.errors?.join(', ') ??
              response.message ??
              'Failed to send OTP',
        );
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to send OTP. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify password reset OTP
  Future<bool> verifyPasswordResetOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.verifyPasswordResetOtp(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      if (response.success) {
        return true;
      } else {
        _setError(
          response.errors?.join(', ') ?? response.message ?? 'Invalid OTP',
        );
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Verification failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password with OTP
  Future<bool> resetPassword({
    required String phoneNumber,
    required String otp,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.resetPassword(
        phoneNumber: phoneNumber,
        otp: otp,
        newPassword: newPassword,
      );
      if (response.success) {
        return true;
      } else {
        _setError(
          response.errors?.join(', ') ??
              response.message ??
              'Failed to reset password',
        );
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to reset password. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Change password for logged in user
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.changePassword(
        phoneNumber: _currentUser!.phone,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (response.success) {
        return true;
      } else {
        _setError(
          response.errors?.join(', ') ??
              response.message ??
              'Failed to change password',
        );
        return false;
      }
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to change password. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile picture via auth endpoint
  Future<String?> updateProfilePicture(String imagePath) async {
    if (_currentUser == null) return null;

    _setLoading(true);
    _clearError();

    try {
      final imageUrl = await _authService.updateProfilePicture(
        userId: _currentUser!.id,
        imagePath: imagePath,
      );

      // Update current user with new image
      _currentUser = api.User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        email: _currentUser!.email,
        avatar: imageUrl,
        licenseNumber: _currentUser!.licenseNumber,
        vehicleNumber: _currentUser!.vehicleNumber,
      );

      // Update in storage
      await _tokenStorage.saveUserData(
        userId: _currentUser!.id,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        email: _currentUser!.email,
        avatar: imageUrl,
      );

      notifyListeners();
      return imageUrl;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to update profile picture. Please try again.');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user avatar/profile photo
  Future<String?> updateUserAvatar(String imagePath) async {
    if (_currentUser == null) return null;

    _setLoading(true);
    _clearError();

    try {
      final avatarUrl = await _userService.uploadAvatar(imagePath);

      // Update current user with new avatar
      _currentUser = api.User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        email: _currentUser!.email,
        avatar: avatarUrl,
        licenseNumber: _currentUser!.licenseNumber,
        vehicleNumber: _currentUser!.vehicleNumber,
      );

      // Update in storage
      await _tokenStorage.saveUserData(
        userId: _currentUser!.id,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        email: _currentUser!.email,
        avatar: avatarUrl,
      );

      notifyListeners();
      return avatarUrl;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to upload avatar. Please try again.');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
