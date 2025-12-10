import 'core/config/environment.dart';
import 'main.dart';

/// Production environment entry point
///
/// Run with: flutter run -t lib/main_production.dart --flavor production --release
/// Build with: flutter build apk -t lib/main_production.dart --flavor production --release
/// Build AAB: flutter build appbundle -t lib/main_production.dart --flavor production --release
void main() async {
  await initializeApp(Environment.production);
}
