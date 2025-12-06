import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';

/// Authentication repository implementation using Supabase
class AuthRepositoryImpl {
  final SupabaseClient supabase;
  final Logger _logger = Logger();

  AuthRepositoryImpl({required this.supabase});

  /// Get current user
  UserEntity? get currentUser {
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    final userData = supabase.auth.currentUser;
    if (userData == null) return null;

    return UserEntity(
      id: userData.id,
      phoneNumber: userData.phone ?? '',
      societyId: AppConstants.societyId,
      createdAt: DateTime.parse(userData.createdAt),
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => supabase.auth.currentSession != null;

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      _logger.i('Sending OTP to +91$phoneNumber');

      await supabase.auth.signInWithOtp(
        phone: '+91$phoneNumber',
      );

      _logger.i('OTP sent successfully');
    } on AuthException catch (e) {
      _logger.e('Auth error sending OTP: ${e.message}');
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Error sending OTP: $e');
      throw AuthException(message: 'Failed to send OTP. Please try again.');
    }
  }

  /// Verify OTP and authenticate
  Future<UserEntity> verifyOtp(String phoneNumber, String otp) async {
    try {
      _logger.i('Verifying OTP for +91$phoneNumber');

      final response = await supabase.auth.verifyOTP(
        phone: '+91$phoneNumber',
        token: otp,
        type: OtpType.sms,
      );

      if (response.session == null) {
        throw const AuthException(message: 'Invalid OTP. Please try again.');
      }

      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Failed to authenticate.');
      }

      _logger.i('OTP verified successfully');

      // Check if user profile exists
      final existingProfile = await _getUserProfile(user.id);

      if (existingProfile != null) {
        return existingProfile;
      }

      // Create new user profile
      return await _createUserProfile(user.id, phoneNumber);
    } on AuthException catch (e) {
      _logger.e('Auth error verifying OTP: ${e.message}');
      if (e.message.contains('Invalid') || e.message.contains('expired')) {
        throw const AuthException(message: 'Invalid or expired OTP.');
      }
      rethrow;
    } catch (e) {
      _logger.e('Error verifying OTP: $e');
      throw AuthException(message: 'Verification failed. Please try again.');
    }
  }

  /// Get user profile from database
  Future<UserEntity?> _getUserProfile(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserModel.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching user profile: $e');
      return null;
    }
  }

  /// Create user profile in database
  Future<UserEntity> _createUserProfile(
      String userId, String phoneNumber) async {
    try {
      final userData = {
        'id': userId,
        'phone_number': phoneNumber,
        'society_id': AppConstants.societyId,
        'is_profile_complete': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('users').insert(userData);

      return UserModel.fromJson(userData);
    } catch (e) {
      _logger.e('Error creating user profile: $e');
      // Return basic user entity even if profile creation fails
      return UserEntity(
        id: userId,
        phoneNumber: phoneNumber,
        societyId: AppConstants.societyId,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Get current user profile
  Future<UserEntity?> getUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return _getUserProfile(userId);
  }

  /// Update user profile
  Future<UserEntity> updateProfile({
    required String name,
    required String flatNumber,
    String? tower,
    String? email,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException(message: 'Not authenticated');
      }

      final updateData = {
        'name': name,
        'flat_number': flatNumber,
        'tower': tower,
        'email': email,
        'is_profile_complete': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      _logger.i('Profile updated successfully');
      return UserModel.fromJson(response);
    } catch (e) {
      _logger.e('Error updating profile: $e');
      throw AuthException(message: 'Failed to update profile.');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      _logger.i('Signed out successfully');
    } catch (e) {
      _logger.e('Error signing out: $e');
      throw AuthException(message: 'Failed to sign out.');
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Soft delete - mark as deleted
      await supabase.from('users').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await signOut();
      _logger.i('Account deleted successfully');
    } catch (e) {
      _logger.e('Error deleting account: $e');
      throw AuthException(message: 'Failed to delete account.');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Refresh session
  Future<void> refreshSession() async {
    try {
      await supabase.auth.refreshSession();
    } catch (e) {
      _logger.e('Error refreshing session: $e');
    }
  }

  /// Update FCM token
  Future<void> updateFcmToken(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      _logger.i('FCM token updated');
    } catch (e) {
      _logger.e('Error updating FCM token: $e');
    }
  }
}
