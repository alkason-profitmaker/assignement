import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../config/environment.dart';

/// Centralized logging system for PrintHub
///
/// Features:
/// - Different log levels (debug, info, warning, error)
/// - Automatic environment-based filtering
/// - Structured logging with tags
/// - Crash reporting integration ready
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const String _tag = 'PrintHub';

  /// Initialize logger (call in main())
  static void initialize() {
    FlutterError.onError = (details) {
      AppLogger.error(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
      );
      // In production, send to crash reporting service
      if (AppConfig.enableCrashlytics) {
        _reportToCrashlytics(details.exception, details.stack);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error(
        'Platform Error',
        error: error,
        stackTrace: stack,
      );
      if (AppConfig.enableCrashlytics) {
        _reportToCrashlytics(error, stack);
      }
      return true;
    };
  }

  /// Debug level logging (development only)
  static void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!AppConfig.enableLogging) return;
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// Info level logging
  static void info(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!AppConfig.enableLogging) return;
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// Warning level logging
  static void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, tag: tag, data: data);
  }

  /// Error level logging
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Network request logging
  static void network(
    String method,
    String url, {
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (!AppConfig.enableLogging) return;

    final data = <String, dynamic>{
      'method': method,
      'url': url,
      if (statusCode != null) 'status': statusCode,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
    };

    if (statusCode != null && statusCode >= 400) {
      _log(LogLevel.error, 'HTTP $method $url → $statusCode', tag: 'Network', data: data);
    } else {
      _log(LogLevel.info, 'HTTP $method $url → ${statusCode ?? 'pending'}', tag: 'Network', data: data);
    }
  }

  /// Analytics event logging
  static void analytics(String event, {Map<String, dynamic>? parameters}) {
    if (!AppConfig.enableAnalytics) return;

    debug('Analytics: $event', tag: 'Analytics', data: parameters);
    // In production, send to analytics service
    // FirebaseAnalytics.instance.logEvent(name: event, parameters: parameters);
  }

  /// User action logging
  static void userAction(String action, {String? screen, Map<String, dynamic>? data}) {
    debug('User: $action', tag: 'UserAction', data: {
      if (screen != null) 'screen': screen,
      ...?data,
    });
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? _tag;
    final prefix = '[${level.name.toUpperCase()}][$logTag]';

    final buffer = StringBuffer()
      ..write('$timestamp $prefix $message');

    if (data != null && data.isNotEmpty) {
      buffer.write(' | data: $data');
    }

    if (error != null) {
      buffer.write('\nError: $error');
    }

    final logMessage = buffer.toString();

    // Console output
    if (kDebugMode) {
      developer.log(
        logMessage,
        name: logTag,
        level: level.value,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // In production, could write to file or send to logging service
    if (level == LogLevel.error && AppConfig.enableCrashlytics) {
      _reportToCrashlytics(error, stackTrace, message: message);
    }
  }

  static void _reportToCrashlytics(
    Object? error,
    StackTrace? stackTrace, {
    String? message,
  }) {
    // Crash reporting integration point - enable when Firebase is configured
    // To enable: Add firebase_crashlytics dependency and uncomment:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}

enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  final int value;
  const LogLevel(this.value);
}
