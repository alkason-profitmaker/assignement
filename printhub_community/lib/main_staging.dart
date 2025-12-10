import 'core/config/environment.dart';
import 'main.dart';

/// Staging environment entry point
///
/// Run with: flutter run -t lib/main_staging.dart --flavor staging
/// Build with: flutter build apk -t lib/main_staging.dart --flavor staging
void main() async {
  await initializeApp(Environment.staging);
}
