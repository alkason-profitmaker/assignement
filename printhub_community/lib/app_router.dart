import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/auth/presentation/pages/onboarding_screen.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/auth/presentation/pages/otp_verification_screen.dart';
import 'features/auth/presentation/pages/profile_setup_screen.dart';
import 'features/home/presentation/pages/home_screen.dart';
import 'features/upload/presentation/pages/upload_document_screen.dart';
import 'features/upload/presentation/pages/document_preview_screen.dart';
import 'features/payment/presentation/pages/payment_screen.dart';
import 'features/payment/presentation/pages/payment_success_screen.dart';
import 'features/print_job/presentation/pages/print_status_screen.dart';
import 'features/history/presentation/pages/print_history_screen.dart';
import 'features/profile/presentation/pages/profile_screen.dart';
import 'features/profile/presentation/pages/help_support_screen.dart';
import 'features/profile/presentation/pages/settings_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final phoneNumber = state.extra as String? ?? '';
          return OtpVerificationScreen(phoneNumber: phoneNumber);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Main App Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Upload Flow
      GoRoute(
        path: '/upload',
        name: 'upload',
        builder: (context, state) => const UploadDocumentScreen(),
      ),
      GoRoute(
        path: '/preview',
        name: 'preview',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return DocumentPreviewScreen(
            filePath: args?['filePath'] ?? '',
            fileName: args?['fileName'] ?? '',
            fileSize: args?['fileSize'] ?? 0,
          );
        },
      ),

      // Payment Flow
      GoRoute(
        path: '/payment',
        name: 'payment',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return PaymentScreen(
            printJobId: args?['printJobId'] ?? '',
            amount: args?['amount'] ?? 0.0,
            pageCount: args?['pageCount'] ?? 0,
            colorPages: args?['colorPages'] ?? 0,
            bwPages: args?['bwPages'] ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/payment-success',
        name: 'payment-success',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return PaymentSuccessScreen(
            printJobId: args?['printJobId'] ?? '',
            amount: args?['amount'] ?? 0.0,
            pickupCode: args?['pickupCode'] ?? '',
          );
        },
      ),

      // Print Job Status
      GoRoute(
        path: '/print-status/:jobId',
        name: 'print-status',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return PrintStatusScreen(jobId: jobId);
        },
      ),

      // History
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const PrintHistoryScreen(),
      ),

      // Profile & Settings
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final isLoggedIn = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp-verification' ||
          state.matchedLocation == '/profile-setup';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isSplash = state.matchedLocation == '/splash';

      // Allow splash screen
      if (isSplash) return null;

      // If not logged in and not on auth pages, redirect to login
      if (!isLoggedIn && !isLoggingIn && !isOnboarding) {
        return '/onboarding';
      }

      // If logged in and on auth pages, redirect to home
      if (isLoggedIn && (isLoggingIn || isOnboarding)) {
        return '/home';
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
