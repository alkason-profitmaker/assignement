/// Standardized API exceptions for PrintHub
///
/// Provides consistent error handling across the app with:
/// - User-friendly messages
/// - Detailed error info for debugging
/// - Retry logic support
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic data;
  final Object? originalError;
  final ApiExceptionType type;

  const ApiException({
    required this.message,
    required this.type,
    this.code,
    this.statusCode,
    this.data,
    this.originalError,
  });

  /// Network/connectivity errors
  factory ApiException.network(String message, {Object? originalError}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.network,
      code: 'NETWORK_ERROR',
      originalError: originalError,
    );
  }

  /// Request timeout
  factory ApiException.timeout(String message, {Object? originalError}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.timeout,
      code: 'TIMEOUT',
      originalError: originalError,
    );
  }

  /// 400 Bad Request
  factory ApiException.badRequest(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.badRequest,
      code: 'BAD_REQUEST',
      statusCode: 400,
      data: data,
    );
  }

  /// 401 Unauthorized
  factory ApiException.unauthorized(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.unauthorized,
      code: 'UNAUTHORIZED',
      statusCode: 401,
      data: data,
    );
  }

  /// 403 Forbidden
  factory ApiException.forbidden(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.forbidden,
      code: 'FORBIDDEN',
      statusCode: 403,
      data: data,
    );
  }

  /// 404 Not Found
  factory ApiException.notFound(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.notFound,
      code: 'NOT_FOUND',
      statusCode: 404,
      data: data,
    );
  }

  /// 422 Validation Error
  factory ApiException.validation(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.validation,
      code: 'VALIDATION_ERROR',
      statusCode: 422,
      data: data,
    );
  }

  /// 429 Rate Limited
  factory ApiException.rateLimited(String message, {dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.rateLimited,
      code: 'RATE_LIMITED',
      statusCode: 429,
      data: data,
    );
  }

  /// 5xx Server Error
  factory ApiException.server(String message, {int? statusCode, dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.server,
      code: 'SERVER_ERROR',
      statusCode: statusCode ?? 500,
      data: data,
    );
  }

  /// Unknown error
  factory ApiException.unknown(String message, {int? statusCode, dynamic data}) {
    return ApiException(
      message: message,
      type: ApiExceptionType.unknown,
      code: 'UNKNOWN_ERROR',
      statusCode: statusCode,
      data: data,
    );
  }

  /// Whether this error should trigger a retry
  bool get shouldRetry {
    switch (type) {
      case ApiExceptionType.network:
      case ApiExceptionType.timeout:
      case ApiExceptionType.server:
      case ApiExceptionType.rateLimited:
        return true;
      default:
        return false;
    }
  }

  /// User-friendly error message
  String get userMessage {
    switch (type) {
      case ApiExceptionType.network:
        return 'Please check your internet connection and try again.';
      case ApiExceptionType.timeout:
        return 'The request took too long. Please try again.';
      case ApiExceptionType.unauthorized:
        return 'Your session has expired. Please login again.';
      case ApiExceptionType.forbidden:
        return 'You don\'t have permission to perform this action.';
      case ApiExceptionType.notFound:
        return 'The requested resource was not found.';
      case ApiExceptionType.validation:
        return message;
      case ApiExceptionType.rateLimited:
        return 'Too many requests. Please wait a moment and try again.';
      case ApiExceptionType.server:
        return 'Something went wrong on our end. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  String toString() => 'ApiException: [$code] $message (status: $statusCode)';
}

enum ApiExceptionType {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  unknown,
}
