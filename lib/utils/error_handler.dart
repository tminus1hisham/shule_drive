import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_exceptions.dart';

/// Error Handler - Centralized error handling with fallback mechanisms
class ErrorHandler {
  /// Generic error message for users
  static const String genericErrorMessage = 
      'Something went wrong. Please try again.';
  
  /// Network error message
  static const String networkErrorMessage = 
      'No internet connection. Please check your network.';
  
  /// Server error message
  static const String serverErrorMessage = 
      'Server error. Please try again later.';
  
  /// Timeout error message
  static const String timeoutErrorMessage = 
      'Request timed out. Please try again.';

  /// Handle API errors and return user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return networkErrorMessage;
    } else if (error is TimeoutException) {
      return timeoutErrorMessage;
    } else if (error is UnauthorizedException) {
      return 'Session expired. Please login again.';
    } else if (error is NotFoundException) {
      return 'Resource not found.';
    } else if (error is ValidationException) {
      return error.message;
    } else if (error is ServerException) {
      return serverErrorMessage;
    } else if (error is ApiException) {
      return error.message;
    } else {
      return genericErrorMessage;
    }
  }

  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    return error is NetworkException || 
           error is TimeoutException || 
           error is ServerException;
  }

  /// Show error snackbar
  static void showErrorSnackBar(
    BuildContext context, 
    String message, {
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF6B9B5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Execute API call with retry logic
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() apiCall,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    VoidCallback? onRetry,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await apiCall();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries || !isRetryable(e)) {
          rethrow;
        }
        
        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
        onRetry?.call();
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  /// Safe API call with fallback buffer
  static Future<T?> safeApiCall<T>({
    required Future<T> Function() apiCall,
    required T fallbackValue,
    BuildContext? context,
    bool showError = true,
    String? errorMessage,
  }) async {
    try {
      return await apiCall();
    } catch (e) {
      debugPrint('API Error: $e');
      
      if (context != null && showError) {
        showErrorSnackBar(
          context,
          errorMessage ?? getErrorMessage(e),
        );
      }
      
      return fallbackValue;
    }
  }

  /// Parse JSON safely with fallback
  static Map<String, dynamic> safeJsonParse(
    String jsonString, {
    Map<String, dynamic> fallback = const {},
  }) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON Parse Error: $e');
      return fallback;
    }
  }

  /// Get value from map safely with fallback
  static T? getValue<T>(
    Map<String, dynamic> map,
    String key, {
    T? fallback,
    List<String> alternativeKeys = const [],
  }) {
    // Try primary key
    if (map.containsKey(key) && map[key] != null) {
      return map[key] as T?;
    }
    
    // Try alternative keys
    for (final altKey in alternativeKeys) {
      if (map.containsKey(altKey) && map[altKey] != null) {
        return map[altKey] as T?;
      }
    }
    
    return fallback;
  }
}

/// Mixin for screens that need error handling
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;
  String? _errorMessage;
  int _retryCount = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void setLoading(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  void setError(String? error) {
    if (mounted) {
      setState(() => _errorMessage = error);
    }
  }

  void clearError() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _retryCount = 0;
      });
    }
  }

  Future<void> handleApiCall({
    required Future<void> Function() apiCall,
    bool showLoading = true,
    bool showError = true,
    VoidCallback? onSuccess,
    int maxRetries = 3,
  }) async {
    if (showLoading) setLoading(true);
    setError(null);

    try {
      await ErrorHandler.executeWithRetry(
        apiCall: apiCall,
        maxRetries: maxRetries,
        onRetry: () => _retryCount++,
      );
      
      onSuccess?.call();
      _retryCount = 0;
    } catch (e) {
      final message = ErrorHandler.getErrorMessage(e);
      setError(message);
      
      if (showError && mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message,
          onRetry: isRetryable(e) ? () => handleApiCall(
            apiCall: apiCall,
            showLoading: showLoading,
            showError: showError,
            onSuccess: onSuccess,
            maxRetries: maxRetries,
          ) : null,
        );
      }
    } finally {
      if (showLoading) setLoading(false);
    }
  }

  bool isRetryable(dynamic error) {
    return ErrorHandler.isRetryable(error);
  }

  Widget buildErrorWidget({
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              customMessage ?? _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (_retryCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Retry attempt: $_retryCount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
