import 'package:equatable/equatable.dart';

/// Base failure class for all application errors
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  List<Object?> get props => [message, code];
}

/// Server/API related failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    super.originalError,
  });

  factory ServerFailure.fromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return const ServerFailure(
          message: 'Bad request. Please check your input.',
          code: '400',
        );
      case 401:
        return const ServerFailure(
          message: 'Unauthorized. Please login again.',
          code: '401',
        );
      case 403:
        return const ServerFailure(
          message: 'Access denied. You don\'t have permission.',
          code: '403',
        );
      case 404:
        return const ServerFailure(
          message: 'Resource not found.',
          code: '404',
        );
      case 500:
        return const ServerFailure(
          message: 'Server error. Please try again later.',
          code: '500',
        );
      case 503:
        return const ServerFailure(
          message: 'Service unavailable. Please try again later.',
          code: '503',
        );
      default:
        return ServerFailure(
          message: 'Server error occurred. Status: $statusCode',
          code: statusCode.toString(),
        );
    }
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

/// Cache/Storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to access local storage.',
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalError,
  });

  factory AuthFailure.invalidOtp() => const AuthFailure(
        message: 'Invalid OTP. Please try again.',
        code: 'INVALID_OTP',
      );

  factory AuthFailure.otpExpired() => const AuthFailure(
        message: 'OTP has expired. Please request a new one.',
        code: 'OTP_EXPIRED',
      );

  factory AuthFailure.sessionExpired() => const AuthFailure(
        message: 'Your session has expired. Please login again.',
        code: 'SESSION_EXPIRED',
      );

  factory AuthFailure.tooManyAttempts() => const AuthFailure(
        message: 'Too many attempts. Please try again later.',
        code: 'TOO_MANY_ATTEMPTS',
      );

  factory AuthFailure.invalidPhone() => const AuthFailure(
        message: 'Invalid phone number. Please enter a valid 10-digit number.',
        code: 'INVALID_PHONE',
      );
}

/// Payment failures
class PaymentFailure extends Failure {
  const PaymentFailure({
    required super.message,
    super.code = 'PAYMENT_ERROR',
    super.originalError,
  });

  factory PaymentFailure.cancelled() => const PaymentFailure(
        message: 'Payment was cancelled.',
        code: 'PAYMENT_CANCELLED',
      );

  factory PaymentFailure.failed() => const PaymentFailure(
        message: 'Payment failed. Please try again.',
        code: 'PAYMENT_FAILED',
      );

  factory PaymentFailure.timeout() => const PaymentFailure(
        message: 'Payment timed out. Please try again.',
        code: 'PAYMENT_TIMEOUT',
      );

  factory PaymentFailure.insufficientFunds() => const PaymentFailure(
        message: 'Insufficient funds. Please try another payment method.',
        code: 'INSUFFICIENT_FUNDS',
      );
}

/// File/Upload failures
class FileFailure extends Failure {
  const FileFailure({
    required super.message,
    super.code = 'FILE_ERROR',
    super.originalError,
  });

  factory FileFailure.tooLarge(int maxSizeMb) => FileFailure(
        message: 'File size exceeds the maximum limit of $maxSizeMb MB.',
        code: 'FILE_TOO_LARGE',
      );

  factory FileFailure.invalidType(List<String> allowedTypes) => FileFailure(
        message:
            'Invalid file type. Allowed types: ${allowedTypes.join(", ")}.',
        code: 'INVALID_FILE_TYPE',
      );

  factory FileFailure.uploadFailed() => const FileFailure(
        message: 'Failed to upload file. Please try again.',
        code: 'UPLOAD_FAILED',
      );

  factory FileFailure.notFound() => const FileFailure(
        message: 'File not found.',
        code: 'FILE_NOT_FOUND',
      );

  factory FileFailure.corruptedPdf() => const FileFailure(
        message: 'The PDF file appears to be corrupted.',
        code: 'CORRUPTED_PDF',
      );

  factory FileFailure.tooManyPages(int maxPages) => FileFailure(
        message: 'Document exceeds maximum $maxPages pages allowed.',
        code: 'TOO_MANY_PAGES',
      );
}

/// Print job failures
class PrintFailure extends Failure {
  const PrintFailure({
    required super.message,
    super.code = 'PRINT_ERROR',
    super.originalError,
  });

  factory PrintFailure.printerOffline() => const PrintFailure(
        message: 'Printer is currently offline. Please try again later.',
        code: 'PRINTER_OFFLINE',
      );

  factory PrintFailure.paperEmpty() => const PrintFailure(
        message: 'Paper tray is empty. Please wait while we refill.',
        code: 'PAPER_EMPTY',
      );

  factory PrintFailure.inkLow() => const PrintFailure(
        message: 'Ink is running low. Please try again shortly.',
        code: 'INK_LOW',
      );

  factory PrintFailure.jobFailed() => const PrintFailure(
        message: 'Print job failed. Your payment will be refunded.',
        code: 'JOB_FAILED',
      );

  factory PrintFailure.jobNotFound() => const PrintFailure(
        message: 'Print job not found.',
        code: 'JOB_NOT_FOUND',
      );

  factory PrintFailure.jobExpired() => const PrintFailure(
        message: 'This print job has expired.',
        code: 'JOB_EXPIRED',
      );
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
  });
}

/// Unknown/Generic failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
  });
}
