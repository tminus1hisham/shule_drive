/// Base API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Network Exception - No internet connection
class NetworkException extends ApiException {
  NetworkException() : super(
    message: 'No internet connection',
    statusCode: 0,
  );
}

/// Timeout Exception - Request took too long
class TimeoutException extends ApiException {
  TimeoutException() : super(
    message: 'Request timeout',
    statusCode: 408,
  );
}

/// Unauthorized Exception - 401
class UnauthorizedException extends ApiException {
  UnauthorizedException({String message = 'Unauthorized'}) : super(
    message: message,
    statusCode: 401,
  );
}

/// Forbidden Exception - 403
class ForbiddenException extends ApiException {
  ForbiddenException({String message = 'Access forbidden'}) : super(
    message: message,
    statusCode: 403,
  );
}

/// Not Found Exception - 404
class NotFoundException extends ApiException {
  NotFoundException({String message = 'Resource not found'}) : super(
    message: message,
    statusCode: 404,
  );
}

/// Validation Exception - 422
class ValidationException extends ApiException {
  ValidationException({
    String message = 'Validation failed',
    Map<String, dynamic>? errors,
  }) : super(
    message: message,
    statusCode: 422,
    errors: errors,
  );
}

/// Server Exception - 500
class ServerException extends ApiException {
  ServerException({String message = 'Server error'}) : super(
    message: message,
    statusCode: 500,
  );
}

/// Bad Request Exception - 400
class BadRequestException extends ApiException {
  BadRequestException({String message = 'Bad request'}) : super(
    message: message,
    statusCode: 400,
  );
}
