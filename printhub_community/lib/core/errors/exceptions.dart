/// Base exception class for all application exceptions
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'AppException: $message (Code: $code)';
}

/// Server/API related exceptions
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalException,
  });

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Network connectivity exceptions
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
    super.code = 'NETWORK_ERROR',
    super.originalException,
  });
}

/// Cache/Storage exceptions
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error occurred',
    super.code = 'CACHE_ERROR',
    super.originalException,
  });
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalException,
  });
}

/// Payment exceptions
class PaymentException extends AppException {
  const PaymentException({
    required super.message,
    super.code = 'PAYMENT_ERROR',
    super.originalException,
  });
}

/// File handling exceptions
class FileException extends AppException {
  const FileException({
    required super.message,
    super.code = 'FILE_ERROR',
    super.originalException,
  });
}

/// Print job exceptions
class PrintException extends AppException {
  const PrintException({
    required super.message,
    super.code = 'PRINT_ERROR',
    super.originalException,
  });
}

/// Validation exceptions
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalException,
  });
}
