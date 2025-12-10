import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';

/// Provider for SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Provider for DocumentService
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

/// Provider for PaytmService
/// Note: In production, get merchant credentials from society config
final paytmServiceProvider = Provider.family<PaytmService, PaytmConfig>((ref, config) {
  return PaytmService(
    merchantId: config.merchantId,
    merchantKey: config.merchantKey,
    isProduction: config.isProduction,
  );
});

/// Provider for EpsonService
/// Note: In production, get credentials from station config
final epsonServiceProvider = Provider.family<EpsonService, EpsonConfig>((ref, config) {
  return EpsonService(
    clientId: config.clientId,
    clientSecret: config.clientSecret,
  );
});

/// Configuration for Paytm service
class PaytmConfig {
  final String merchantId;
  final String merchantKey;
  final bool isProduction;

  PaytmConfig({
    required this.merchantId,
    required this.merchantKey,
    this.isProduction = false,
  });
}

/// Configuration for Epson service
class EpsonConfig {
  final String clientId;
  final String clientSecret;

  EpsonConfig({
    required this.clientId,
    required this.clientSecret,
  });
}
