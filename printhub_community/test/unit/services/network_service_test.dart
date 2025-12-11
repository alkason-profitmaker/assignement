import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/services/network_service.dart';

void main() {
  group('NetworkValidationResult', () {
    test('connected factory creates valid result', () {
      final result = NetworkValidationResult.connected(ConnectivityType.wifi);

      expect(result.isConnected, true);
      expect(result.hasInternet, true);
      expect(result.canProceed, true);
      expect(result.connectivityType, ConnectivityType.wifi);
      expect(result.errorMessage, isNull);
    });

    test('noConnection factory creates disconnected result', () {
      final result = NetworkValidationResult.noConnection();

      expect(result.isConnected, false);
      expect(result.hasInternet, false);
      expect(result.canProceed, false);
      expect(result.errorMessage, isNotNull);
    });

    test('noInternet factory creates connected but no internet result', () {
      final result = NetworkValidationResult.noInternet();

      expect(result.isConnected, true);
      expect(result.hasInternet, false);
      expect(result.canProceed, false);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('ConnectivityType', () {
    test('has all expected values', () {
      expect(ConnectivityType.values, contains(ConnectivityType.wifi));
      expect(ConnectivityType.values, contains(ConnectivityType.mobile));
      expect(ConnectivityType.values, contains(ConnectivityType.ethernet));
      expect(ConnectivityType.values, contains(ConnectivityType.vpn));
      expect(ConnectivityType.values, contains(ConnectivityType.none));
      expect(ConnectivityType.values, contains(ConnectivityType.other));
    });
  });
}
