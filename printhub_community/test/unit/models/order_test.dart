import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/models/order.dart';

void main() {
  group('PrintOrder', () {
    group('calculatePrice', () {
      test('calculates correct price for B/W pages only', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 10,
          colorPages: 0,
          copies: 1,
        );
        expect(price, 3000); // 10 * 300 paise
      });

      test('calculates correct price for color pages only', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 0,
          colorPages: 5,
          copies: 1,
        );
        expect(price, 5000); // 5 * 1000 paise
      });

      test('calculates correct price for mixed pages', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 4,
          colorPages: 1,
          copies: 1,
        );
        expect(price, 2200); // (4*300) + (1*1000)
      });

      test('multiplies by copies correctly', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 5,
          colorPages: 0,
          copies: 3,
        );
        expect(price, 4500); // 5 * 300 * 3
      });

      test('handles zero pages', () {
        final price = PrintOrder.calculatePrice(
          bwPages: 0,
          colorPages: 0,
          copies: 1,
        );
        expect(price, 0);
      });
    });

    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final json = {
          'id': 'order-123',
          'order_number': 123,
          'user_id': 'user-456',
          'society_id': 'society-789',
          'station_id': 'station-101',
          'file_name': 'document.pdf',
          'total_pages': 10,
          'bw_pages': 8,
          'color_pages': 2,
          'copies': 1,
          'amount_paise': 4400,
          'final_amount_paise': 4400,
          'print_status': 'WAITING',
          'payment_status': 'PENDING',
          'created_at': '2024-01-15T10:30:00Z',
          'updated_at': '2024-01-15T10:30:00Z',
          'expires_at': '2024-01-15T12:30:00Z',
        };

        final order = PrintOrder.fromJson(json);

        expect(order.id, 'order-123');
        expect(order.orderNumber, 123);
        expect(order.fileName, 'document.pdf');
        expect(order.totalPages, 10);
        expect(order.bwPages, 8);
        expect(order.colorPages, 2);
        expect(order.amountPaise, 4400);
      });
    });
  });

  group('CreateOrderRequest', () {
    test('creates valid request', () {
      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        copies: 2,
        fileBytes: [1, 2, 3, 4, 5],
      );

      expect(request.stationId, 'station-123');
      expect(request.fileName, 'test.pdf');
      expect(request.totalPages, 5);
      expect(request.copies, 2);
    });

    test('toJson produces correct output', () {
      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        fileHash: 'abc123',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        copies: 2,
        fileBytes: [1, 2, 3],
      );

      final json = request.toJson();

      expect(json['station_id'], 'station-123');
      expect(json['file_name'], 'test.pdf');
      expect(json['file_hash'], 'abc123');
      expect(json['total_pages'], 5);
    });
  });
}
