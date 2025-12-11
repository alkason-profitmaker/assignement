import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/error/failures.dart';

void main() {
  group('ServerFailure', () {
    test('fromStatusCode returns correct message for 401', () {
      final failure = ServerFailure.fromStatusCode(401);
      expect(failure.message, contains('Unauthorized'));
      expect(failure.statusCode, 401);
      expect(failure.code, 'HTTP_401');
    });

    test('fromStatusCode returns correct message for 404', () {
      final failure = ServerFailure.fromStatusCode(404);
      expect(failure.message, contains('not found'));
      expect(failure.statusCode, 404);
    });

    test('fromStatusCode returns correct message for 500', () {
      final failure = ServerFailure.fromStatusCode(500);
      expect(failure.message, contains('Server error'));
      expect(failure.statusCode, 500);
    });
  });

  group('AuthFailure', () {
    test('invalidCredentials has correct code', () {
      final failure = AuthFailure.invalidCredentials();
      expect(failure.code, 'INVALID_CREDENTIALS');
    });

    test('sessionExpired has correct code', () {
      final failure = AuthFailure.sessionExpired();
      expect(failure.code, 'SESSION_EXPIRED');
    });

    test('otpExpired has correct code', () {
      final failure = AuthFailure.otpExpired();
      expect(failure.code, 'OTP_EXPIRED');
    });
  });

  group('PaymentFailure', () {
    test('failed has correct code', () {
      final failure = PaymentFailure.failed();
      expect(failure.code, 'PAYMENT_FAILED');
    });

    test('timeout has correct code', () {
      final failure = PaymentFailure.timeout();
      expect(failure.code, 'PAYMENT_TIMEOUT');
    });

    test('refundFailed has correct code', () {
      final failure = PaymentFailure.refundFailed();
      expect(failure.code, 'REFUND_FAILED');
    });
  });

  group('PrintFailure', () {
    test('printerOffline has correct code', () {
      final failure = PrintFailure.printerOffline();
      expect(failure.code, 'PRINTER_OFFLINE');
    });

    test('paperJam has correct code', () {
      final failure = PrintFailure.paperJam();
      expect(failure.code, 'PAPER_JAM');
    });
  });

  group('DocumentFailure', () {
    test('tooLarge includes size in message', () {
      final failure = DocumentFailure.tooLarge(10);
      expect(failure.message, contains('10'));
      expect(failure.code, 'FILE_TOO_LARGE');
    });

    test('unsupportedFormat includes format in message', () {
      final failure = DocumentFailure.unsupportedFormat('.xyz');
      expect(failure.message, contains('.xyz'));
      expect(failure.code, 'UNSUPPORTED_FORMAT');
    });
  });

  group('ValidationFailure', () {
    test('stores field errors', () {
      final failure = ValidationFailure(
        message: 'Validation failed',
        fieldErrors: {'email': 'Invalid'},
      );
      expect(failure.fieldErrors?['email'], 'Invalid');
      expect(failure.code, 'VALIDATION_ERROR');
    });
  });
}
