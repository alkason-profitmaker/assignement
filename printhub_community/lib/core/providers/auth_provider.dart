import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import 'service_providers.dart';

/// Auth state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsRegistration,
  error,
}

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;
  final bool otpSent;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.otpSent = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool? otpSent,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      otpSent: otpSent ?? this.otpSent,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseService _supabaseService;

  AuthNotifier(this._supabaseService) : super(AuthState());

  /// Check current auth status
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      if (!_supabaseService.isAuthenticated) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final user = await _supabaseService.getCurrentUser();
      if (user == null) {
        // User authenticated but no profile - needs registration
        state = state.copyWith(status: AuthStatus.needsRegistration);
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Send OTP to phone
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await _supabaseService.sendOtp(phone);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        otpSent: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send OTP: ${e.toString()}',
        otpSent: false,
      );
      return false;
    }
  }

  /// Verify OTP
  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await _supabaseService.verifyOtp(phone, otp);

      // Check if user has profile
      final user = await _supabaseService.getCurrentUser();
      if (user == null) {
        state = state.copyWith(status: AuthStatus.needsRegistration);
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid OTP. Please try again.',
      );
      return false;
    }
  }

  /// Complete registration
  Future<bool> completeRegistration({
    required String phone,
    required String name,
    required String societyId,
    required String flatNumber,
    String? email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final user = await _supabaseService.createUser(
        phone: phone,
        name: name,
        societyId: societyId,
        flatNumber: flatNumber,
        email: email,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Registration failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
      state = AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Sign out failed: ${e.toString()}',
      );
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? flatNumber,
  }) async {
    if (state.user == null) return false;

    try {
      final updatedUser = await _supabaseService.updateUser(
        userId: state.user!.id,
        name: name,
        email: email,
        flatNumber: flatNumber,
      );

      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Update failed: ${e.toString()}',
      );
      return false;
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(supabaseService);
});

/// Current user provider
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
