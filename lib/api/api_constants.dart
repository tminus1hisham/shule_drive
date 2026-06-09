import '../services/app_config.dart';

/// API Constants - Base URL and timeout configuration for the HTTP client.
///
/// Endpoint paths are NOT defined here; `Endpoints` (lib/api/endpoints.dart)
/// is the single source of truth for routes.
class ApiConstants {
  // Base URLs
  // Resolved from --dart-define, .env, then AppConfig defaults.
  static String get baseUrl => appConfig.apiBaseUrl;

  // Development URL (for local testing)
  static const String devBaseUrl = 'http://localhost:8000/api';

  // Timeout durations
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
}

/// HTTP Status Codes
class HttpStatus {
  static const int ok = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;
}

/// API Error Messages
class ApiErrorMessages {
  static const String noInternet = 'No internet connection';
  static const String timeout = 'Request timeout';
  static const String serverError = 'Server error occurred';
  static const String unknownError = 'An unknown error occurred';
  static const String invalidCredentials = 'Invalid credentials';
  static const String sessionExpired = 'Session expired. Please login again';
}
