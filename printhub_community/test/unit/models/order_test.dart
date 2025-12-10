import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/constants/app_constants.dart';
import 'package:printhub_community/core/models/order.dart';

void main() {
  group('PrintOrder', () {
    group('calculatePrice', () {
      test('should calculate price for B/W pages only', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 10,
          colorPages: 0,
          copies: 1,
        );

        // 10 pages * 300 paise = 3000 paise (₹30)
        expect(price, equals(3000));
      });

      test('should calculate price for color pages only', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 0,
          colorPages: 5,
          copies: 1,
        );

        // 5 pages * 1000 paise = 5000 paise (₹50)
        expect(price, equals(5000));
      });

      test('should calculate price for mixed pages', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 8,
          colorPages: 2,
          copies: 1,
        );

        // (8 * 300) + (2 * 1000) = 2400 + 2000 = 4400 paise (₹44)
        expect(price, equals(4400));
      });

      test('should multiply by copies', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 5,
          colorPages: 0,
          copies: 3,
        );

        // (5 * 300) * 3 = 4500 paise (₹45)
        expect(price, equals(4500));
      });

      test('should return 0 for no pages', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 0,
          colorPages: 0,
          copies: 1,
        );

        expect(price, equals(0));
      });
    });

    group('status checks', () {
      test('isPending should be true for PENDING payment status', () {
        final order = _createOrder(paymentStatus: 'PENDING');
        expect(order.isPending, isTrue);
        expect(order.isPaid, isFalse);
      });

      test('isPaid should be true for PAID payment status', () {
        final order = _createOrder(paymentStatus: 'PAID');
        expect(order.isPaid, isTrue);
        expect(order.isPending, isFalse);
      });

      test('isCompleted should be true for DONE print status', () {
        final order = _createOrder(printStatus: 'DONE');
        expect(order.isCompleted, isTrue);
        expect(order.isFailed, isFalse);
      });

      test('isFailed should be true for FAILED print status', () {
        final order = _createOrder(printStatus: 'FAILED');
        expect(order.isFailed, isTrue);
        expect(order.isCompleted, isFalse);
      });

      test('isExpired should be true when expires_at is in the past', () {
        final order = _createOrder(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(order.isExpired, isTrue);
      });

      test('isExpired should be false when expires_at is in the future', () {
        final order = _createOrder(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(order.isExpired, isFalse);
      });
    });

    group('amount calculations', () {
      test('amountRupees should convert paise to rupees', () {
        final order = _createOrder(amountPaise: 4500);
        expect(order.amountRupees, equals(45.0));
      });

      test('finalAmountRupees should convert paise to rupees', () {
        final order = _createOrder(finalAmountPaise: 3000);
        expect(order.finalAmountRupees, equals(30.0));
      });

      test('creditsUsedRupees should convert paise to rupees', () {
        final order = _createOrder(creditsUsedPaise: 600);
        expect(order.creditsUsedRupees, equals(6.0));
      });
    });

    group('canBeRefunded', () {
      test('should be true for paid, non-refunded, non-completed orders', () {
        final order = _createOrder(
          paymentStatus: 'PAID',
          printStatus: 'PRINTING',
        );
        expect(order.canBeRefunded, isTrue);
      });

      test('should be false for already refunded orders', () {
        final order = _createOrder(
          paymentStatus: 'REFUNDED',
          printStatus: 'FAILED',
        );
        expect(order.canBeRefunded, isFalse);
      });

      test('should be false for completed orders', () {
        final order = _createOrder(
          paymentStatus: 'PAID',
          printStatus: 'DONE',
        );
        expect(order.canBeRefunded, isFalse);
      });

      test('should be false for pending orders', () {
        final order = _createOrder(
          paymentStatus: 'PENDING',
          printStatus: 'WAITING',
        );
        expect(order.canBeRefunded, isFalse);
      });
    });
  });
}

PrintOrder _createOrder({
  String paymentStatus = 'PENDING',
  String printStatus = 'WAITING',
  int amountPaise = 3000,
  int creditsUsedPaise = 0,
  int finalAmountPaise = 3000,
  DateTime? expiresAt,
}) {
  return PrintOrder(
    id: 'test-order-id',
    orderNumber: 1001,
    userId: 'test-user-id',
    societyId: 'test-society-id',
    stationId: 'test-station-id',
    fileName: 'test.pdf',
    totalPages: 10,
    bwPages: 10,
    colorPages: 0,
    copies: 1,
    amountPaise: amountPaise,
    creditsUsedPaise: creditsUsedPaise,
    finalAmountPaise: finalAmountPaise,
    paymentStatus: paymentStatus,
    printStatus: printStatus,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 2)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
