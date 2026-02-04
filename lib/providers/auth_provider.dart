import 'package:flutter/material.dart';
import '../api/api.dart' as api;
import '../api/services/auth_service.dart';
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
    'avatar': _currentUser?.avatar ?? 'https://ui-avatars.com/api/?name=${_currentUser?.name ?? "User"}&background=random',
    'role': _currentUser?.role ?? 'unknown',
    'licenseNumber': _currentUser?.licenseNumber,
    'vehicleNumber': _currentUser?.vehicleNumber,
  };

  /// Initialize auth state (call on app startup)
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          _currentUser = user;
          _userRole = UserRole.fromString(user.role);
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
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
        _setError(response.errors?.join(', ') ?? response.message ?? 'Login failed');
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
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
    } catch (e) {
      // Even if server logout fails, clear local data
    } finally {
      // Clear tokens from storage
      await _tokenStorage.clearAll();
      await api.ApiClient().clearAuthToken();
      
      _currentUser = null;
      _userRole = UserRole.unknown;
      _isAuthenticated = false;
      _setLoading(false);
      notifyListeners();
    }
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
        _setError(response.errors?.join(', ') ?? response.message ?? 'Failed to send OTP');
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
        _setError(response.errors?.join(', ') ?? response.message ?? 'Invalid OTP');
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
        _setError(response.errors?.join(', ') ?? response.message ?? 'Failed to reset password');
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
