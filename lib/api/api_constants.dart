/// API Constants - Base URLs and Endpoints
class ApiConstants {
  // Base URLs
  // Staging API URL (without /api suffix - endpoints include it)
  static const String baseUrl = 'https://staging-api.shuledrive.com';
  
  // Development URL (for local testing)
  static const String devBaseUrl = 'http://localhost:8000/api';
  
  // Timeout durations
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  
  // API Endpoints
  static const String login = '/auth/login';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  
  // User Endpoints
  static const String userProfile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String changePassword = '/user/change-password';
  
  // Trip Endpoints
  static const String trips = '/trips';
  static const String tripDetails = '/trips/{id}';
  static const String startTrip = '/trips/start';
  static const String endTrip = '/trips/{id}/end';
  static const String activeTrip = '/trips/active';
  
  // Student Endpoints
  static const String students = '/students';
  static const String studentDetails = '/students/{id}';
  static const String updateStudentStatus = '/students/{id}/status';
  
  // Children Endpoints
  static const String children = '/children';
  static const String childDetails = '/children/{id}';
  
  // Notifications Endpoints
  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  
  // Chat Endpoints
  static const String conversations = '/chat/conversations';
  static const String messages = '/chat/messages';
  static const String sendMessage = '/chat/send';
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
