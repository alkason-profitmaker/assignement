/// Environment configuration for PrintHub Community
///
/// This supports three environments:
/// - Development: For local testing with mock data
/// - Staging: For QA testing with staging servers
/// - Production: For live app deployment
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  final Environment environment;
  final String appName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String paytmBaseUrl;
  final String epsonBaseUrl;
  final bool enableLogging;
  final bool enableCrashlytics;
  final bool enableAnalytics;
  final Duration apiTimeout;
  final int maxRetries;

  const EnvironmentConfig._({
    required this.environment,
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.paytmBaseUrl,
    required this.epsonBaseUrl,
    required this.enableLogging,
    required this.enableCrashlytics,
    required this.enableAnalytics,
    required this.apiTimeout,
    required this.maxRetries,
  });

  /// Development configuration
  factory EnvironmentConfig.development() {
    return const EnvironmentConfig._(
      environment: Environment.development,
      appName: 'PrintHub Dev',
      supabaseUrl: 'https://your-dev-project.supabase.co',
      supabaseAnonKey: 'your-dev-anon-key',
      paytmBaseUrl: 'https://securegw-stage.paytm.in',
      epsonBaseUrl: 'https://api.epsonconnect.com',
      enableLogging: true,
      enableCrashlytics: false,
      enableAnalytics: false,
      apiTimeout: Duration(seconds: 60),
      maxRetries: 5,
    );
  }

  /// Staging configuration
  factory EnvironmentConfig.staging() {
    return const EnvironmentConfig._(
      environment: Environment.staging,
      appName: 'PrintHub Staging',
      supabaseUrl: 'https://your-staging-project.supabase.co',
      supabaseAnonKey: 'your-staging-anon-key',
      paytmBaseUrl: 'https://securegw-stage.paytm.in',
      epsonBaseUrl: 'https://api.epsonconnect.com',
      enableLogging: true,
      enableCrashlytics: true,
      enableAnalytics: false,
      apiTimeout: Duration(seconds: 45),
      maxRetries: 3,
    );
  }

  /// Production configuration
  factory EnvironmentConfig.production() {
    return const EnvironmentConfig._(
      environment: Environment.production,
      appName: 'PrintHub',
      supabaseUrl: 'https://your-prod-project.supabase.co',
      supabaseAnonKey: 'your-prod-anon-key',
      paytmBaseUrl: 'https://securegw.paytm.in',
      epsonBaseUrl: 'https://api.epsonconnect.com',
      enableLogging: false,
      enableCrashlytics: true,
      enableAnalytics: true,
      apiTimeout: Duration(seconds: 30),
      maxRetries: 3,
    );
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
  bool get isDebugMode => isDevelopment || isStaging;
}

/// Global app configuration singleton
class AppConfig {
  static late EnvironmentConfig _config;

  static void initialize(Environment env) {
    switch (env) {
      case Environment.development:
        _config = EnvironmentConfig.development();
        break;
      case Environment.staging:
        _config = EnvironmentConfig.staging();
        break;
      case Environment.production:
        _config = EnvironmentConfig.production();
        break;
    }
  }

  static EnvironmentConfig get instance => _config;

  // Convenience getters
  static Environment get environment => _config.environment;
  static String get appName => _config.appName;
  static String get supabaseUrl => _config.supabaseUrl;
  static String get supabaseAnonKey => _config.supabaseAnonKey;
  static String get paytmBaseUrl => _config.paytmBaseUrl;
  static String get epsonBaseUrl => _config.epsonBaseUrl;
  static bool get enableLogging => _config.enableLogging;
  static bool get enableCrashlytics => _config.enableCrashlytics;
  static bool get enableAnalytics => _config.enableAnalytics;
  static Duration get apiTimeout => _config.apiTimeout;
  static int get maxRetries => _config.maxRetries;
  static bool get isProduction => _config.isProduction;
  static bool get isDebugMode => _config.isDebugMode;
}
