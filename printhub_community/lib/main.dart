import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_bloc_observer.dart';
import 'core/utils/notification_service.dart';
import 'core/network/connectivity_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/print_job/presentation/bloc/print_job_bloc.dart';
import 'features/print_job/data/repositories/print_job_repository_impl.dart';
import 'features/payment/presentation/bloc/payment_bloc.dart';
import 'features/upload/presentation/bloc/upload_bloc.dart';
import 'app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUIOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Notification Service
  await NotificationService.instance.initialize();

  // Initialize Connectivity Service
  await ConnectivityService.instance.initialize();

  // Set up Bloc observer for debugging
  Bloc.observer = AppBlocObserver();

  runApp(const PrintHubApp());
}

class PrintHubApp extends StatelessWidget {
  const PrintHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (context) => AuthRepositoryImpl(
            supabase: Supabase.instance.client,
          ),
        ),
        RepositoryProvider(
          create: (context) => PrintJobRepositoryImpl(
            supabase: Supabase.instance.client,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepositoryImpl>(),
            )..add(CheckAuthStatusEvent()),
          ),
          BlocProvider(
            create: (context) => PrintJobBloc(
              printJobRepository: context.read<PrintJobRepositoryImpl>(),
            ),
          ),
          BlocProvider(
            create: (context) => PaymentBloc(),
          ),
          BlocProvider(
            create: (context) => UploadBloc(
              supabase: Supabase.instance.client,
            ),
          ),
        ],
        child: MaterialApp.router(
          title: 'PrintHub Community',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
