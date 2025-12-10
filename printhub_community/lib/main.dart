import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'features/auth/screens/splash_screen.dart';

/// Main entry point for the PrintHub Community app
///
/// For environment-specific builds, use:
/// - main_development.dart for development
/// - main_staging.dart for staging
/// - main_production.dart for production
///
/// This file defaults to development for direct flutter run
void main() async {
  await initializeApp(Environment.development);
}

/// Initialize the application with the specified environment
Future<void> initializeApp(Environment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  AppConfig.initialize(environment);

  // Initialize logging
  AppLogger.initialize();
  AppLogger.info('Starting PrintHub Community', tag: 'App');
  AppLogger.info('Environment: ${AppConfig.environment.name}', tag: 'App');

  try {
    // Initialize Supabase with environment-specific credentials
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: AppConfig.isDebugMode,
    );
    AppLogger.info('Supabase initialized successfully', tag: 'App');
  } catch (e, stackTrace) {
    AppLogger.error(
      'Failed to initialize Supabase',
      error: e,
      stackTrace: stackTrace,
      tag: 'App',
    );
    // Continue anyway - app will show error state when trying to use Supabase
  }

  runApp(
    const ProviderScope(
      child: PrintHubApp(),
    ),
  );
}

class PrintHubApp extends StatelessWidget {
  const PrintHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
