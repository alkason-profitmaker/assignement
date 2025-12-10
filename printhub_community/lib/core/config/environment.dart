import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment types supported by the application
enum Environment {
  development,
  staging,
  production;

  String get envFileName {
    switch (this) {
      case Environment.development:
        return '.env.development';
      case Environment.staging:
        return '.env.staging';
      case Environment.production:
        return '.env.production';
    }
  }
}

/// Configuration validation exception
class ConfigurationException implements Exception {
  final String message;
  final List<String> missingKeys;

  ConfigurationException(this.message, [this.missingKeys = const []]);

  @override
  String toString() {
    if (missingKeys.isEmpty) {
      return 'ConfigurationException: $message';
    }
    return 'ConfigurationException: $message\nMissing keys: ${missingKeys.join(', ')}';
  }
}

/// Environment configuration loaded from .env files
class EnvironmentConfig {
  final Environment environment;

  // Supabase
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? supabaseServiceRoleKey;

  // Paytm
  final String paytmMerchantId;
  final String paytmMerchantKey;
  final String paytmWebsite;
  final String paytmIndustryType;
  final String paytmChannelId;
  final String paytmBaseUrl;

  // Epson Connect
  final String epsonClientId;
  final String epsonClientSecret;
  final String epsonRefreshToken;
  final String epsonBaseUrl;

  // App Settings
  final String appName;
  final bool debugMode;
  final bool enableLogging;
  final bool enableCrashlytics;
  final bool enableAnalytics;
  final Duration apiTimeout;
  final int maxRetries;

  const EnvironmentConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseServiceRoleKey,
    required this.paytmMerchantId,
    required this.paytmMerchantKey,
    required this.paytmWebsite,
    required this.paytmIndustryType,
    required this.paytmChannelId,
    required this.paytmBaseUrl,
    required this.epsonClientId,
    required this.epsonClientSecret,
    required this.epsonRefreshToken,
    required this.epsonBaseUrl,
    required this.appName,
    required this.debugMode,
    required this.enableLogging,
    required this.enableCrashlytics,
    required this.enableAnalytics,
    required this.apiTimeout,
    required this.maxRetries,
  });

  /// Load configuration from .env file
  static Future<EnvironmentConfig> load(Environment env) async {
    await dotenv.load(fileName: env.envFileName);

    // Validate required keys
    final requiredKeys = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'PAYTM_MERCHANT_ID',
      'PAYTM_MERCHANT_KEY',
      'EPSON_CLIENT_ID',
      'EPSON_CLIENT_SECRET',
      'EPSON_REFRESH_TOKEN',
    ];

    final missingKeys = <String>[];
    for (final key in requiredKeys) {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        missingKeys.add(key);
      }
    }

    if (missingKeys.isNotEmpty) {
      throw ConfigurationException(
        'Required environment variables are not configured. '
        'Please update your ${env.envFileName} file.',
        missingKeys,
      );
    }

    return EnvironmentConfig._(
      environment: env,
      supabaseUrl: _getRequired('SUPABASE_URL'),
      supabaseAnonKey: _getRequired('SUPABASE_ANON_KEY'),
      supabaseServiceRoleKey: dotenv.env['SUPABASE_SERVICE_ROLE_KEY'],
      paytmMerchantId: _getRequired('PAYTM_MERCHANT_ID'),
      paytmMerchantKey: _getRequired('PAYTM_MERCHANT_KEY'),
      paytmWebsite: dotenv.env['PAYTM_WEBSITE'] ?? 'WEBSTAGING',
      paytmIndustryType: dotenv.env['PAYTM_INDUSTRY_TYPE'] ?? 'Retail',
      paytmChannelId: dotenv.env['PAYTM_CHANNEL_ID'] ?? 'WAP',
      paytmBaseUrl: dotenv.env['PAYTM_BASE_URL'] ?? 'https://securegw-stage.paytm.in',
      epsonClientId: _getRequired('EPSON_CLIENT_ID'),
      epsonClientSecret: _getRequired('EPSON_CLIENT_SECRET'),
      epsonRefreshToken: _getRequired('EPSON_REFRESH_TOKEN'),
      epsonBaseUrl: dotenv.env['EPSON_BASE_URL'] ?? 'https://api.epsonconnect.com',
      appName: dotenv.env['APP_NAME'] ?? 'PrintHub',
      debugMode: _getBool('DEBUG_MODE', env != Environment.production),
      enableLogging: _getBool('ENABLE_LOGGING', env != Environment.production),
      enableCrashlytics: _getBool('ENABLE_CRASHLYTICS', env != Environment.development),
      enableAnalytics: _getBool('ENABLE_ANALYTICS', env == Environment.production),
      apiTimeout: Duration(seconds: _getInt('API_TIMEOUT', 30)),
      maxRetries: _getInt('MAX_RETRIES', 3),
    );
  }

  static String _getRequired(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw ConfigurationException('Required key $key is not set');
    }
    return value;
  }

  static bool _getBool(String key, bool defaultValue) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }

  static int _getInt(String key, int defaultValue) {
    final value = dotenv.env[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
  bool get isDebugMode => isDevelopment || isStaging;
}

/// Global app configuration singleton
class AppConfig {
  static EnvironmentConfig? _config;
  static bool _initialized = false;

  /// Initialize configuration from .env file
  static Future<void> initialize(Environment env) async {
    if (_initialized) return;
    _config = await EnvironmentConfig.load(env);
    _initialized = true;
  }

  /// Check if configuration is initialized
  static bool get isInitialized => _initialized;

  /// Get current configuration instance
  static EnvironmentConfig get instance {
    if (_config == null) {
      throw ConfigurationException(
        'AppConfig not initialized. Call AppConfig.initialize() first.',
      );
    }
    return _config!;
  }

  // Convenience getters
  static Environment get environment => instance.environment;
  static String get appName => instance.appName;
  static String get supabaseUrl => instance.supabaseUrl;
  static String get supabaseAnonKey => instance.supabaseAnonKey;
  static String? get supabaseServiceRoleKey => instance.supabaseServiceRoleKey;
  static String get paytmMerchantId => instance.paytmMerchantId;
  static String get paytmMerchantKey => instance.paytmMerchantKey;
  static String get paytmWebsite => instance.paytmWebsite;
  static String get paytmIndustryType => instance.paytmIndustryType;
  static String get paytmChannelId => instance.paytmChannelId;
  static String get paytmBaseUrl => instance.paytmBaseUrl;
  static String get epsonClientId => instance.epsonClientId;
  static String get epsonClientSecret => instance.epsonClientSecret;
  static String get epsonRefreshToken => instance.epsonRefreshToken;
  static String get epsonBaseUrl => instance.epsonBaseUrl;
  static bool get enableLogging => instance.enableLogging;
  static bool get enableCrashlytics => instance.enableCrashlytics;
  static bool get enableAnalytics => instance.enableAnalytics;
  static Duration get apiTimeout => instance.apiTimeout;
  static int get maxRetries => instance.maxRetries;
  static bool get isProduction => instance.isProduction;
  static bool get isDebugMode => instance.isDebugMode;
}
