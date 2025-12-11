import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printhub_community/core/models/models.dart';
import 'package:printhub_community/core/services/services.dart';
import 'package:printhub_community/core/error/failures.dart';
import 'package:printhub_community/data/repositories/auth_repository.dart';

class MockSupabaseService extends Mock implements SupabaseService {}
class MockAuthResponse extends Mock implements AuthResponse {}
class MockUser extends Mock implements User {}

void main() {
  late AuthRepositoryImpl repository;
  late MockSupabaseService mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseService();
    repository = AuthRepositoryImpl(mockSupabase);
  });

  group('requestOtp', () {
    test('returns validation error for invalid phone number', () async {
      final result = await repository.requestOtp('123'); // Too short

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns validation error for invalid prefix', () async {
      final result = await repository.requestOtp('1234567890'); // Doesn't start with 6-9

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('sends OTP for valid phone number', () async {
      when(() => mockSupabase.signInWithOtp(any())).thenAnswer((_) async {});

      final result = await repository.requestOtp('9876543210');

      expect(result.isRight(), true);
      verify(() => mockSupabase.signInWithOtp('9876543210')).called(1);
    });

    test('returns rate limit error when rate limited', () async {
      when(() => mockSupabase.signInWithOtp(any()))
          .thenThrow(Exception('rate limit exceeded'));

      final result = await repository.requestOtp('9876543210');

      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).code, 'RATE_LIMITED');
        },
        (_) => fail('Expected failure'),
      );
    });
  });

  group('verifyOtp', () {
    test('returns validation error for invalid OTP format', () async {
      final result = await repository.verifyOtp('9876543210', '123'); // Too short

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns validation error for non-numeric OTP', () async {
      final result = await repository.verifyOtp('9876543210', 'abcdef');

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns user not found when no user profile exists', () async {
      final mockResponse = MockAuthResponse();
      final mockUser = MockUser();

      when(() => mockResponse.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-123');
      when(() => mockSupabase.verifyOtp(any(), any()))
          .thenAnswer((_) async => mockResponse);
      when(() => mockSupabase.getUserProfile(any()))
          .thenAnswer((_) async => null);

      final result = await repository.verifyOtp('9876543210', '123456');

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns OTP expired error when OTP has expired', () async {
      when(() => mockSupabase.verifyOtp(any(), any()))
          .thenThrow(Exception('OTP expired'));

      final result = await repository.verifyOtp('9876543210', '123456');

      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect((failure as AuthFailure).code, 'OTP_EXPIRED');
        },
        (_) => fail('Expected failure'),
      );
    });
  });

  group('signOut', () {
    test('signs out successfully', () async {
      when(() => mockSupabase.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result.isRight(), true);
      verify(() => mockSupabase.signOut()).called(1);
    });

    test('returns failure on error', () async {
      when(() => mockSupabase.signOut()).thenThrow(Exception('Sign out failed'));

      final result = await repository.signOut();

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });

  group('isAuthenticated', () {
    test('returns true when authenticated', () {
      when(() => mockSupabase.isAuthenticated).thenReturn(true);

      expect(repository.isAuthenticated, true);
    });

    test('returns false when not authenticated', () {
      when(() => mockSupabase.isAuthenticated).thenReturn(false);

      expect(repository.isAuthenticated, false);
    });
  });
}
