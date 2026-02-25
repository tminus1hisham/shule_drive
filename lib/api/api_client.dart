import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/token_storage.dart';
import 'api_constants.dart';
import 'api_exceptions.dart';

/// API Client - Handles all HTTP requests with token persistence
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // HTTP Client
  late final http.Client _client = http.Client();
  
  // Token storage
  final TokenStorage _tokenStorage = TokenStorage();
  
  // Auth token in memory
  String? _authToken;
  
  // Base URL
  String get baseUrl => ApiConstants.baseUrl;
  
  /// Initialize and load token from storage
  /// Only loads token if one exists - call this on app startup
  Future<void> init() async {
    // Only load token if we haven't explicitly cleared it
    _authToken ??= await _tokenStorage.getAccessToken();
  }
  
  /// Set auth token after login (persists to storage)
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _tokenStorage.saveAuthTokens(accessToken: token);
  }
  
  /// Save both access and refresh tokens
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _authToken = accessToken;
    await _tokenStorage.saveAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
  
  /// Clear auth token on logout
  Future<void> clearAuthToken() async {
    // Clear in-memory token first
    _authToken = null;
    
    // Clear all tokens from persistent storage
    await _tokenStorage.clearAll();
  }
  
  /// Force clear any cached token (useful for logout scenarios)
  void forceClearToken() {
    _authToken = null;
  }
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    _authToken ??= await _tokenStorage.getAccessToken();
    return _authToken != null;
  }
  
  /// Get headers for requests
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (requiresAuth) {
      // Load token if not in memory
      _authToken ??= await _tokenStorage.getAccessToken();
      
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }
    }
    
    return headers;
  }
  
  /// Handle HTTP response with better error handling
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    debugPrint('📥 API Response: status=$statusCode, body=${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
    
    // Handle empty response body
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {}; // Return empty map for successful empty responses
      } else {
        throw ServerException(message: 'Server returned empty response (status: $statusCode)');
      }
    }
    
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      debugPrint('JSON Parse Error: ${response.body}');
      throw ApiException(
        message: 'Invalid server response format',
        statusCode: statusCode,
      );
    }
    
    // Success responses
    if (statusCode >= 200 && statusCode < 300) {
      return body;
    }
    
    // Error responses - extract message
    String message = 'Request failed';
    if (body is Map) {
      message = body['message'] ?? 
                body['error'] ?? 
                body['errorMessage'] ??
                body['title'] ??
                'Request failed';
    }
    
    // Check if the response body contains a database timeout error
    final responseBody = response.body.toLowerCase();
    final bool isDbTimeout = responseBody.contains('taskcanceledexception') ||
                             responseBody.contains('timeout') ||
                             responseBody.contains('npgsql') ||
                             responseBody.contains('a task was canceled');
    
    // Throw appropriate exception
    switch (statusCode) {
      case HttpStatus.badRequest:
        throw BadRequestException(message: message);
      case HttpStatus.unauthorized:
        throw UnauthorizedException(message: message);
      case HttpStatus.forbidden:
        throw ForbiddenException(message: message);
      case HttpStatus.notFound:
        throw NotFoundException(message: message);
      case 408: // Request Timeout
        throw TimeoutException();
      case 422: // Validation error
        throw ValidationException(
          message: message,
          errors: body is Map ? body['errors'] : null,
        );
      case 429: // Too Many Requests
        throw ApiException(message: 'Too many requests. Please try again later.');
      case 500:
        // Check if it's a database timeout error
        if (isDbTimeout) {
          throw ServerUnavailableException(
            message: 'Server is temporarily unavailable due to high load. Please try again in a moment.',
          );
        }
        throw ServerException(message: 'Server error. Please try again later.');
      case 502:
      case 503:
      case 504:
        throw ServerUnavailableException(message: 'Server is temporarily unavailable. Please try again later.');
      default:
        throw ApiException(message: message, statusCode: statusCode);
    }
  }
  
  /// Handle exceptions
  Exception _handleException(dynamic error, {String? endpoint}) {
    if (error is SocketException) {
      return NetworkException();
    } else if (error is TimeoutException) {
      // Client-side timeout (Flutter app timed out waiting for server)
      return TimeoutException();
    } else if (error is ApiException) {
      return error;
    } else if (error is FormatException) {
      // JSON parse error - usually happens when server returns HTML error page or garbage
      debugPrint('⚠️ JSON Parse Error for $endpoint: $error');
      return ServerUnavailableException(
        message: 'Server returned an invalid response. Please try again later.',
      );
    } else {
      return ApiException(
        message: error.toString(),
        statusCode: 0,
      );
    }
  }
  
  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      // Debug logging
      debugPrint('🔷 API Request: GET $uri');
      
      final response = await _client
          .get(uri, headers: headers)
          .timeout(
            timeout ?? const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      // Debug logging for response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ API Response: ${response.statusCode} from GET $endpoint');
      } else {
        debugPrint('❌ API Error: ${response.statusCode} from GET $endpoint');
        debugPrint('Response body: ${response.body}');
      }
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ API Exception on GET $endpoint: $e');
      throw _handleException(e, endpoint: endpoint);
    }
  }
  
  /// POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      // Debug logging (remove in production)
      debugPrint('API Request: POST $uri');
      debugPrint('Request Body: $body');
      
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e, endpoint: endpoint);
    }
  }
  
  /// PUT request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e, endpoint: endpoint);
    }
  }
  
  /// PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e);
    }
  }
  
  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      // Add content-type header if body is provided
      if (body != null) {
        headers['Content-Type'] = 'application/json';
      }
      
      final response = await _client
          .delete(
            uri, 
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e, endpoint: endpoint);
    }
  }
  
  /// Multipart POST request (for file uploads)
  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add auth header
      if (requiresAuth) {
        _authToken ??= await _tokenStorage.getAccessToken();
        if (_authToken != null) {
          request.headers['Authorization'] = 'Bearer $_authToken';
        }
      }
      
      // Add fields
      request.fields.addAll(fields);
      
      // Add files
      if (files != null) {
        request.files.addAll(files);
      }
      
      final streamedResponse = await request.send().timeout(
        const Duration(milliseconds: ApiConstants.connectionTimeout),
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e, endpoint: endpoint);
    }
  }
}
