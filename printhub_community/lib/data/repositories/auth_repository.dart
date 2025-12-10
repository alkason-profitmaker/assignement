import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/models/user.dart';
import '../../core/services/supabase_service.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Request OTP for phone number
  Future<Either<Failure, void>> requestOtp(String phoneNumber);

  /// Verify OTP and sign in
  Future<Either<Failure, AppUser>> verifyOtp(String phoneNumber, String otp);

  /// Get current authenticated user
  Future<Either<Failure, AppUser?>> getCurrentUser();

  /// Sign out
  Future<Either<Failure, void>> signOut();

  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Stream of auth state changes
  Stream<AppUser?> get authStateChanges;
}

/// Implementation of AuthRepository using Supabase
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseService _supabaseService;

  AuthRepositoryImpl(this._supabaseService);

  @override
  Future<Either<Failure, void>> requestOtp(String phoneNumber) async {
    try {
      // Validate phone number format
      if (!_isValidIndianPhone(phoneNumber)) {
        return Left(ValidationFailure(
          message: 'Please enter a valid 10-digit Indian mobile number',
          fieldErrors: {'phone': 'Invalid phone number'},
        ));
      }

      await _supabaseService.signInWithOtp(phoneNumber);
      return const Right(null);
    } catch (e) {
      if (e.toString().contains('rate limit')) {
        return Left(ServerFailure(
          message: 'Too many OTP requests. Please wait before trying again.',
          code: 'RATE_LIMITED',
          originalError: e,
        ));
      }
      return Left(ServerFailure(
        message: 'Failed to send OTP. Please try again.',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, AppUser>> verifyOtp(String phoneNumber, String otp) async {
    try {
      // Validate OTP format
      if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
        return Left(ValidationFailure(
          message: 'Please enter a valid 6-digit OTP',
          fieldErrors: {'otp': 'Invalid OTP format'},
        ));
      }

      final response = await _supabaseService.verifyOtp(phoneNumber, otp);

      if (response.user == null) {
        return Left(AuthFailure.invalidCredentials());
      }

      // Get or create user profile
      final user = await _supabaseService.getUserProfile(response.user!.id);
      if (user == null) {
        return Left(AuthFailure.userNotFound());
      }

      return Right(user);
    } catch (e) {
      if (e.toString().contains('expired')) {
        return Left(AuthFailure.otpExpired());
      }
      if (e.toString().contains('invalid')) {
        return Left(AuthFailure.invalidCredentials());
      }
      return Left(ServerFailure(
        message: 'Verification failed. Please try again.',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, AppUser?>> getCurrentUser() async {
    try {
      final session = _supabaseService.currentSession;
      if (session == null) {
        return const Right(null);
      }

      final user = await _supabaseService.getUserProfile(session.user.id);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch user profile',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _supabaseService.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to sign out',
        originalError: e,
      ));
    }
  }

  @override
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  @override
  Stream<AppUser?> get authStateChanges => _supabaseService.authStateChanges;

  bool _isValidIndianPhone(String phone) {
    // Remove any spaces or dashes
    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');
    // Check for valid Indian mobile number (10 digits starting with 6-9)
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }
}
