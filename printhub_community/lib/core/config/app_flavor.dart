import 'environment.dart';

/// Flavor-specific entry points for the app
///
/// Usage:
/// - flutter run --flavor development -t lib/main_development.dart
/// - flutter run --flavor staging -t lib/main_staging.dart
/// - flutter run --flavor production -t lib/main_production.dart

class AppFlavor {
  static late String _flavor;

  static void setFlavor(String flavor) {
    _flavor = flavor;
    _initEnvironment();
  }

  static String get flavor => _flavor;

  static void _initEnvironment() {
    switch (_flavor) {
      case 'development':
        AppConfig.initialize(Environment.development);
        break;
      case 'staging':
        AppConfig.initialize(Environment.staging);
        break;
      case 'production':
        AppConfig.initialize(Environment.production);
        break;
      default:
        AppConfig.initialize(Environment.development);
    }
  }

  static bool get isDevelopment => _flavor == 'development';
  static bool get isStaging => _flavor == 'staging';
  static bool get isProduction => _flavor == 'production';
}
