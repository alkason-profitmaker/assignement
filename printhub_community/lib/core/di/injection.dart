import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/environment.dart';
import '../services/supabase_service.dart';
import '../services/paytm_service.dart';
import '../services/epson_service.dart';
import '../services/document_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/society_repository.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/repositories/credit_repository.dart';

final getIt = GetIt.instance;

/// Configure all dependencies
Future<void> configureDependencies() async {
  // External dependencies
  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Services
  getIt.registerLazySingleton<SupabaseService>(
    () => SupabaseService(),
  );

  getIt.registerLazySingleton<PaytmService>(
    () => PaytmService(
      merchantId: AppConfig.paytmMerchantId,
      merchantKey: AppConfig.paytmMerchantKey,
      website: AppConfig.paytmWebsite,
      industryType: AppConfig.paytmIndustryType,
      channelId: AppConfig.paytmChannelId,
      baseUrl: AppConfig.paytmBaseUrl,
    ),
  );

  getIt.registerLazySingleton<EpsonService>(
    () => EpsonService(
      clientId: AppConfig.epsonClientId,
      clientSecret: AppConfig.epsonClientSecret,
    ),
  );

  getIt.registerLazySingleton<DocumentService>(
    () => DocumentService(),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      getIt<SupabaseService>(),
      getIt<PaytmService>(),
      getIt<EpsonService>(),
      getIt<DocumentService>(),
    ),
  );

  getIt.registerLazySingleton<SocietyRepository>(
    () => SocietyRepositoryImpl(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<StationRepository>(
    () => StationRepositoryImpl(
      getIt<SupabaseService>(),
      getIt<EpsonService>(),
    ),
  );

  getIt.registerLazySingleton<CreditRepository>(
    () => CreditRepositoryImpl(getIt<SupabaseService>()),
  );
}

/// Reset dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
