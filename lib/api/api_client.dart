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
    
    // Handle empty response body
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {}; // Return empty map for successful empty responses
      } else {
        throw ServerException(message: 'Server returned empty response');
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
      case 502:
      case 503:
      case 504:
        throw ServerException(message: 'Server error. Please try again later.');
      default:
        throw ApiException(message: message, statusCode: statusCode);
    }
  }
  
  /// Handle exceptions
  Exception _handleException(dynamic error) {
    if (error is SocketException) {
      return NetworkException();
    } else if (error is TimeoutException) {
      return TimeoutException();
    } else if (error is ApiException) {
      return error;
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
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .get(uri, headers: headers)
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e);
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
      throw _handleException(e);
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
      throw _handleException(e);
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
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(
            const Duration(milliseconds: ApiConstants.connectionTimeout),
          );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleException(e);
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
      throw _handleException(e);
    }
  }
}
