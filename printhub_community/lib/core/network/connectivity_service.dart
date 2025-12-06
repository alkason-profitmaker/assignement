import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

/// Service to monitor network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final Logger _logger = Logger();

  StreamController<bool>? _connectionStatusController;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Stream of connection status changes
  Stream<bool> get connectionStatusStream {
    _connectionStatusController ??= StreamController<bool>.broadcast();
    return _connectionStatusController!.stream;
  }

  /// Initialize the connectivity service
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final results = await _connectivity.checkConnectivity();
      _isConnected = _isAnyConnected(results);

      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _isConnected = _isAnyConnected(results);
          _connectionStatusController?.add(_isConnected);
          _logger.i('Connectivity changed: $_isConnected');
        },
        onError: (error) {
          _logger.e('Connectivity error: $error');
        },
      );

      _logger.i('ConnectivityService initialized. Connected: $_isConnected');
    } catch (e) {
      _logger.e('Failed to initialize ConnectivityService: $e');
      _isConnected = true; // Assume connected on error
    }
  }

  bool _isAnyConnected(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = _isAnyConnected(results);
      return _isConnected;
    } catch (e) {
      _logger.e('Error checking connectivity: $e');
      return true; // Assume connected on error
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController?.close();
  }
}
