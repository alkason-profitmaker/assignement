import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../core/errors/exceptions.dart';

// ============ EVENTS ============

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

class SendOtpEvent extends AuthEvent {
  final String phoneNumber;

  const SendOtpEvent(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class VerifyOtpEvent extends AuthEvent {
  final String phoneNumber;
  final String otp;

  const VerifyOtpEvent({
    required this.phoneNumber,
    required this.otp,
  });

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class ResendOtpEvent extends AuthEvent {
  final String phoneNumber;

  const ResendOtpEvent(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class UpdateProfileEvent extends AuthEvent {
  final String name;
  final String flatNumber;
  final String? tower;
  final String? email;

  const UpdateProfileEvent({
    required this.name,
    required this.flatNumber,
    this.tower,
    this.email,
  });

  @override
  List<Object?> get props => [name, flatNumber, tower, email];
}

class SignOutEvent extends AuthEvent {}

class DeleteAccountEvent extends AuthEvent {}

// ============ STATES ============

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {
  final String? message;

  const AuthLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class AuthOtpSent extends AuthState {
  final String phoneNumber;

  const AuthOtpSent(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthProfileIncomplete extends AuthState {
  final UserEntity user;

  const AuthProfileIncomplete(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============ BLOC ============

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepositoryImpl authRepository;
  StreamSubscription? _authSubscription;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SendOtpEvent>(_onSendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<ResendOtpEvent>(_onResendOtp);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<SignOutEvent>(_onSignOut);
    on<DeleteAccountEvent>(_onDeleteAccount);

    // Listen to auth state changes
    _authSubscription = authRepository.authStateChanges.listen((state) {
      if (state.session == null) {
        add(CheckAuthStatusEvent());
      }
    });
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (!authRepository.isAuthenticated) {
        emit(AuthUnauthenticated());
        return;
      }

      final user = await authRepository.getUserProfile();
      if (user == null) {
        emit(AuthUnauthenticated());
        return;
      }

      if (!user.hasCompletedProfile) {
        emit(AuthProfileIncomplete(user));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSendOtp(
    SendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Sending OTP...'));

      await authRepository.sendOtp(event.phoneNumber);

      emit(AuthOtpSent(event.phoneNumber));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(const AuthError('Failed to send OTP. Please try again.'));
    }
  }

  Future<void> _onVerifyOtp(
    VerifyOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Verifying OTP...'));

      final user = await authRepository.verifyOtp(
        event.phoneNumber,
        event.otp,
      );

      if (!user.hasCompletedProfile) {
        emit(AuthProfileIncomplete(user));
      } else {
        emit(AuthAuthenticated(user));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
      emit(AuthOtpSent(event.phoneNumber));
    } catch (e) {
      emit(const AuthError('Verification failed. Please try again.'));
      emit(AuthOtpSent(event.phoneNumber));
    }
  }

  Future<void> _onResendOtp(
    ResendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Resending OTP...'));

      await authRepository.sendOtp(event.phoneNumber);

      emit(AuthOtpSent(event.phoneNumber));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
      emit(AuthOtpSent(event.phoneNumber));
    } catch (e) {
      emit(const AuthError('Failed to resend OTP. Please try again.'));
      emit(AuthOtpSent(event.phoneNumber));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Updating profile...'));

      final user = await authRepository.updateProfile(
        name: event.name,
        flatNumber: event.flatNumber,
        tower: event.tower,
        email: event.email,
      );

      emit(AuthAuthenticated(user));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(const AuthError('Failed to update profile. Please try again.'));
    }
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Signing out...'));

      await authRepository.signOut();

      emit(AuthUnauthenticated());
    } catch (e) {
      emit(const AuthError('Failed to sign out.'));
    }
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading(message: 'Deleting account...'));

      await authRepository.deleteAccount();

      emit(AuthUnauthenticated());
    } catch (e) {
      emit(const AuthError('Failed to delete account.'));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
