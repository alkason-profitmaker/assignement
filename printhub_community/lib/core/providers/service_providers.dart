import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/environment.dart';
import '../services/services.dart';

/// Provider for SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Provider for DocumentService
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

/// Provider for NetworkService
final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService();
});

/// Provider for network connectivity stream
final connectivityStreamProvider = StreamProvider<ConnectivityResult>((ref) {
  return ref.watch(networkServiceProvider).connectivityStream;
});

/// Provider for current network status
final isConnectedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(networkServiceProvider).isConnected();
});

/// Provider for PaytmService - uses Edge Functions for secure payment operations
/// NOTE: Merchant credentials are kept server-side for security
final paytmServiceProvider = Provider<PaytmService>((ref) {
  return PaytmService(
    supabaseUrl: AppConfig.supabaseUrl,
    supabaseAnonKey: AppConfig.supabaseAnonKey,
  );
});

/// Provider for EpsonService - uses AppConfig for credentials
final epsonServiceProvider = Provider<EpsonService>((ref) {
  return EpsonService(
    clientId: AppConfig.epsonClientId,
    clientSecret: AppConfig.epsonClientSecret,
  );
});

/// Provider for station-specific Epson service (uses station's printer credentials)
final stationEpsonServiceProvider = Provider.family<EpsonService, EpsonConfig>((ref, config) {
  return EpsonService(
    clientId: config.clientId,
    clientSecret: config.clientSecret,
  );
});

/// Configuration for station-specific Epson service
class EpsonConfig {
  final String clientId;
  final String clientSecret;

  const EpsonConfig({
    required this.clientId,
    required this.clientSecret,
  });
}
