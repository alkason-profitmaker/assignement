import 'core/config/environment.dart';
import 'main.dart';

/// Development environment entry point
///
/// Run with: flutter run -t lib/main_development.dart --flavor development
/// Build with: flutter build apk -t lib/main_development.dart --flavor development
void main() async {
  await initializeApp(Environment.development);
}
