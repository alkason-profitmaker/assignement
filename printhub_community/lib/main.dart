import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
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

  // Initialize logging first
  AppLogger.initialize();
  AppLogger.info('Starting PrintHub Community', tag: 'App');
  AppLogger.info('Environment: ${environment.name}', tag: 'App');

  try {
    // Load environment configuration from .env file
    await AppConfig.initialize(environment);
    AppLogger.info('Configuration loaded successfully', tag: 'App');
  } on ConfigurationException catch (e) {
    AppLogger.error('Configuration error: $e', tag: 'App');
    runApp(ConfigurationErrorApp(error: e));
    return;
  }

  try {
    // Initialize dependency injection
    await configureDependencies();
    AppLogger.info('Dependencies configured', tag: 'App');
  } catch (e, stackTrace) {
    AppLogger.error(
      'Failed to configure dependencies',
      error: e,
      stackTrace: stackTrace,
      tag: 'App',
    );
  }

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
    runApp(InitializationErrorApp(
      error: 'Failed to connect to backend services.\n\nPlease check your internet connection and try again.',
    ));
    return;
  }

  runApp(
    const ProviderScope(
      child: PrintHubApp(),
    ),
  );
}

/// Main application widget
class PrintHubApp extends StatelessWidget {
  const PrintHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
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
    );
  }
}

/// Error screen for configuration issues
class ConfigurationErrorApp extends StatelessWidget {
  final ConfigurationException error;

  const ConfigurationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade700),
                const SizedBox(height: 24),
                Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red.shade800),
                ),
                if (error.missingKeys.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Missing Configuration:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...error.missingKeys.map((key) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• $key',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: Colors.red.shade700,
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Please update your .env file with the required values and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error screen for initialization failures
class InitializationErrorApp extends StatelessWidget {
  final String error;

  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade600),
                const SizedBox(height: 24),
                Text(
                  'Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
