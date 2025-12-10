/// Base failure class for all application errors
abstract class Failure {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'Failure: $message${code != null ? ' ($code)' : ''}';
}

/// Server/Network failures
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });

  factory ServerFailure.fromStatusCode(int statusCode, [String? message]) {
    String defaultMessage;
    switch (statusCode) {
      case 400:
        defaultMessage = 'Bad request';
        break;
      case 401:
        defaultMessage = 'Unauthorized. Please login again.';
        break;
      case 403:
        defaultMessage = 'Access denied';
        break;
      case 404:
        defaultMessage = 'Resource not found';
        break;
      case 422:
        defaultMessage = 'Validation failed';
        break;
      case 429:
        defaultMessage = 'Too many requests. Please try again later.';
        break;
      case 500:
        defaultMessage = 'Server error. Please try again later.';
        break;
      case 503:
        defaultMessage = 'Service unavailable. Please try again later.';
        break;
      default:
        defaultMessage = 'An error occurred';
    }
    return ServerFailure(
      message: message ?? defaultMessage,
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
    );
  }
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
    super.originalError,
  });

  factory AuthFailure.invalidCredentials() => const AuthFailure(
    message: 'Invalid phone number or OTP',
    code: 'INVALID_CREDENTIALS',
  );

  factory AuthFailure.sessionExpired() => const AuthFailure(
    message: 'Session expired. Please login again.',
    code: 'SESSION_EXPIRED',
  );

  factory AuthFailure.userNotFound() => const AuthFailure(
    message: 'User not found. Please register first.',
    code: 'USER_NOT_FOUND',
  );

  factory AuthFailure.otpExpired() => const AuthFailure(
    message: 'OTP has expired. Please request a new one.',
    code: 'OTP_EXPIRED',
  );
}

/// Payment related failures
class PaymentFailure extends Failure {
  const PaymentFailure({
    required super.message,
    super.code,
    super.originalError,
  });

  factory PaymentFailure.failed([String? reason]) => PaymentFailure(
    message: reason ?? 'Payment failed. Please try again.',
    code: 'PAYMENT_FAILED',
  );

  factory PaymentFailure.cancelled() => const PaymentFailure(
    message: 'Payment was cancelled',
    code: 'PAYMENT_CANCELLED',
  );

  factory PaymentFailure.timeout() => const PaymentFailure(
    message: 'Payment timeout. Please try again.',
    code: 'PAYMENT_TIMEOUT',
  );

  factory PaymentFailure.refundFailed([String? reason]) => PaymentFailure(
    message: reason ?? 'Refund failed. Please contact support.',
    code: 'REFUND_FAILED',
  );
}

/// Print related failures
class PrintFailure extends Failure {
  const PrintFailure({
    required super.message,
    super.code,
    super.originalError,
  });

  factory PrintFailure.printerOffline() => const PrintFailure(
    message: 'Printer is offline. Please try another station.',
    code: 'PRINTER_OFFLINE',
  );

  factory PrintFailure.paperJam() => const PrintFailure(
    message: 'Paper jam detected. Please try another station.',
    code: 'PAPER_JAM',
  );

  factory PrintFailure.lowInk() => const PrintFailure(
    message: 'Printer low on ink. Please try another station.',
    code: 'LOW_INK',
  );

  factory PrintFailure.jobFailed([String? reason]) => PrintFailure(
    message: reason ?? 'Print job failed',
    code: 'PRINT_FAILED',
  );

  factory PrintFailure.uploadFailed() => const PrintFailure(
    message: 'Failed to upload document for printing',
    code: 'UPLOAD_FAILED',
  );
}

/// Document processing failures
class DocumentFailure extends Failure {
  const DocumentFailure({
    required super.message,
    super.code,
    super.originalError,
  });

  factory DocumentFailure.tooLarge(int maxSizeMB) => DocumentFailure(
    message: 'File size exceeds $maxSizeMB MB limit',
    code: 'FILE_TOO_LARGE',
  );

  factory DocumentFailure.unsupportedFormat(String format) => DocumentFailure(
    message: 'Unsupported file format: $format',
    code: 'UNSUPPORTED_FORMAT',
  );

  factory DocumentFailure.corrupted() => const DocumentFailure(
    message: 'File is corrupted and cannot be processed',
    code: 'FILE_CORRUPTED',
  );

  factory DocumentFailure.passwordProtected() => const DocumentFailure(
    message: 'Password protected files are not supported',
    code: 'PASSWORD_PROTECTED',
  );

  factory DocumentFailure.tooManyPages(int maxPages) => DocumentFailure(
    message: 'Document exceeds $maxPages page limit',
    code: 'TOO_MANY_PAGES',
  );
}

/// Cache/Storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

/// Validation failures
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
  });
}

/// Unknown/unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
  });
}
