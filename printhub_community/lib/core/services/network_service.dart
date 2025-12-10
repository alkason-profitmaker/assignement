import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../logging/app_logger.dart';

/// Service for network connectivity monitoring and validation
class NetworkService {
  final Connectivity _connectivity = Connectivity();

  StreamController<ConnectivityResult>? _connectivityController;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get connectivityStream {
    _connectivityController ??= StreamController<ConnectivityResult>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _connectivityController!.stream;
  }

  void _startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _connectivityController?.add(result);
      AppLogger.debug('Connectivity changed: $result', tag: 'Network');
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Check if device has network connectivity
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      return result != ConnectivityResult.none;
    } catch (e) {
      AppLogger.warning('Failed to check connectivity', error: e, tag: 'Network');
      return false;
    }
  }

  /// Check if device can reach the internet (actual connectivity test)
  Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      AppLogger.warning('Internet access check failed', error: e, tag: 'Network');
      return false;
    }
  }

  /// Check connectivity to a specific host
  Future<bool> canReachHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current connectivity type
  Future<ConnectivityType> getConnectivityType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

      switch (result) {
        case ConnectivityResult.wifi:
          return ConnectivityType.wifi;
        case ConnectivityResult.mobile:
          return ConnectivityType.mobile;
        case ConnectivityResult.ethernet:
          return ConnectivityType.ethernet;
        case ConnectivityResult.vpn:
          return ConnectivityType.vpn;
        case ConnectivityResult.none:
          return ConnectivityType.none;
        default:
          return ConnectivityType.other;
      }
    } catch (e) {
      return ConnectivityType.none;
    }
  }

  /// Validate network before critical operations
  Future<NetworkValidationResult> validateNetworkForOperation() async {
    final isDeviceConnected = await isConnected();
    if (!isDeviceConnected) {
      return NetworkValidationResult.noConnection();
    }

    final hasInternet = await hasInternetAccess();
    if (!hasInternet) {
      return NetworkValidationResult.noInternet();
    }

    final connectivityType = await getConnectivityType();
    return NetworkValidationResult.connected(connectivityType);
  }

  void dispose() {
    _stopListening();
    _connectivityController?.close();
    _connectivityController = null;
  }
}

/// Types of network connectivity
enum ConnectivityType {
  wifi,
  mobile,
  ethernet,
  vpn,
  other,
  none,
}

/// Result of network validation
class NetworkValidationResult {
  final bool isConnected;
  final bool hasInternet;
  final ConnectivityType? connectivityType;
  final String? errorMessage;

  NetworkValidationResult._({
    required this.isConnected,
    required this.hasInternet,
    this.connectivityType,
    this.errorMessage,
  });

  factory NetworkValidationResult.connected(ConnectivityType type) {
    return NetworkValidationResult._(
      isConnected: true,
      hasInternet: true,
      connectivityType: type,
    );
  }

  factory NetworkValidationResult.noConnection() {
    return NetworkValidationResult._(
      isConnected: false,
      hasInternet: false,
      errorMessage: 'No network connection. Please check your WiFi or mobile data.',
    );
  }

  factory NetworkValidationResult.noInternet() {
    return NetworkValidationResult._(
      isConnected: true,
      hasInternet: false,
      errorMessage: 'Connected to network but no internet access. Please check your connection.',
    );
  }

  bool get canProceed => isConnected && hasInternet;
}
