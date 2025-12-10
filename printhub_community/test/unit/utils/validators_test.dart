import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validatePhone', () {
      test('should return error for empty phone', () {
        expect(Validators.validatePhone(''), isNotNull);
        expect(Validators.validatePhone(null), isNotNull);
      });

      test('should return error for invalid length', () {
        expect(Validators.validatePhone('123'), isNotNull);
        expect(Validators.validatePhone('12345678901'), isNotNull);
      });

      test('should return error for phone not starting with 6-9', () {
        expect(Validators.validatePhone('1234567890'), isNotNull);
        expect(Validators.validatePhone('5234567890'), isNotNull);
      });

      test('should return null for valid Indian mobile number', () {
        expect(Validators.validatePhone('9876543210'), isNull);
        expect(Validators.validatePhone('8765432109'), isNull);
        expect(Validators.validatePhone('7654321098'), isNull);
        expect(Validators.validatePhone('6543210987'), isNull);
      });
    });

    group('validateOtp', () {
      test('should return error for empty OTP', () {
        expect(Validators.validateOtp(''), isNotNull);
        expect(Validators.validateOtp(null), isNotNull);
      });

      test('should return error for invalid length', () {
        expect(Validators.validateOtp('123'), isNotNull);
        expect(Validators.validateOtp('1234567'), isNotNull);
      });

      test('should return error for non-numeric OTP', () {
        expect(Validators.validateOtp('12345a'), isNotNull);
        expect(Validators.validateOtp('abcdef'), isNotNull);
      });

      test('should return null for valid 6-digit OTP', () {
        expect(Validators.validateOtp('123456'), isNull);
        expect(Validators.validateOtp('000000'), isNull);
      });
    });

    group('validateName', () {
      test('should return error for empty name', () {
        expect(Validators.validateName(''), isNotNull);
        expect(Validators.validateName(null), isNotNull);
        expect(Validators.validateName('   '), isNotNull);
      });

      test('should return error for name less than 2 characters', () {
        expect(Validators.validateName('A'), isNotNull);
      });

      test('should return error for name more than 100 characters', () {
        expect(Validators.validateName('A' * 101), isNotNull);
      });

      test('should return null for valid name', () {
        expect(Validators.validateName('John Doe'), isNull);
        expect(Validators.validateName('AB'), isNull);
      });
    });

    group('validateEmail', () {
      test('should return null for empty email (optional)', () {
        expect(Validators.validateEmail(''), isNull);
        expect(Validators.validateEmail(null), isNull);
      });

      test('should return error for invalid email format', () {
        expect(Validators.validateEmail('invalid'), isNotNull);
        expect(Validators.validateEmail('invalid@'), isNotNull);
        expect(Validators.validateEmail('@invalid.com'), isNotNull);
        expect(Validators.validateEmail('invalid@.com'), isNotNull);
      });

      test('should return null for valid email', () {
        expect(Validators.validateEmail('test@example.com'), isNull);
        expect(Validators.validateEmail('user.name@domain.co.in'), isNull);
      });
    });

    group('validateFlatNumber', () {
      test('should return error for empty flat number', () {
        expect(Validators.validateFlatNumber(''), isNotNull);
        expect(Validators.validateFlatNumber(null), isNotNull);
      });

      test('should return error for flat number > 20 chars', () {
        expect(Validators.validateFlatNumber('A' * 21), isNotNull);
      });

      test('should return null for valid flat number', () {
        expect(Validators.validateFlatNumber('A-101'), isNull);
        expect(Validators.validateFlatNumber('B2-304'), isNull);
        expect(Validators.validateFlatNumber('1205'), isNull);
      });
    });

    group('validatePincode', () {
      test('should return error for empty pincode', () {
        expect(Validators.validatePincode(''), isNotNull);
        expect(Validators.validatePincode(null), isNotNull);
      });

      test('should return error for invalid pincode format', () {
        expect(Validators.validatePincode('12345'), isNotNull);
        expect(Validators.validatePincode('1234567'), isNotNull);
        expect(Validators.validatePincode('abcdef'), isNotNull);
      });

      test('should return null for valid 6-digit pincode', () {
        expect(Validators.validatePincode('560034'), isNull);
        expect(Validators.validatePincode('400001'), isNull);
      });
    });

    group('file validators', () {
      test('isValidFileSize should check against limit', () {
        expect(Validators.isValidFileSize(1024 * 1024), isTrue); // 1 MB
        expect(Validators.isValidFileSize(25 * 1024 * 1024), isTrue); // 25 MB
        expect(Validators.isValidFileSize(26 * 1024 * 1024), isFalse); // 26 MB
      });

      test('isValidPageCount should check against limit', () {
        expect(Validators.isValidPageCount(1), isTrue);
        expect(Validators.isValidPageCount(50), isTrue);
        expect(Validators.isValidPageCount(51), isFalse);
        expect(Validators.isValidPageCount(0), isFalse);
        expect(Validators.isValidPageCount(-1), isFalse);
      });

      test('isValidFileExtension should check supported formats', () {
        expect(Validators.isValidFileExtension('document.pdf'), isTrue);
        expect(Validators.isValidFileExtension('photo.jpg'), isTrue);
        expect(Validators.isValidFileExtension('image.jpeg'), isTrue);
        expect(Validators.isValidFileExtension('picture.png'), isTrue);
        expect(Validators.isValidFileExtension('document.PDF'), isTrue);
        expect(Validators.isValidFileExtension('document.doc'), isFalse);
        expect(Validators.isValidFileExtension('document.docx'), isFalse);
      });
    });
  });
}
