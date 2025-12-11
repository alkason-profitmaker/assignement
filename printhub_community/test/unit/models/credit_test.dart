import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/models/credit.dart';

void main() {
  group('Credit', () {
    group('remainingPages', () {
      test('calculates remaining B/W pages correctly', () {
        final credit = Credit(
          id: 'test',
          userId: 'user',
          pagesBw: 10,
          pagesColor: 5,
          pagesBwUsed: 3,
          pagesColorUsed: 1,
          reason: 'Test',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        );

        expect(credit.remainingBwPages, 7);
        expect(credit.remainingColorPages, 4);
      });
    });

    group('isExpired', () {
      test('returns false for future expiry', () {
        final credit = Credit(
          id: 'test',
          userId: 'user',
          pagesBw: 5,
          reason: 'Test',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        );

        expect(credit.isExpired, false);
      });

      test('returns true for past expiry', () {
        final credit = Credit(
          id: 'test',
          userId: 'user',
          pagesBw: 5,
          reason: 'Test',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 31)),
        );

        expect(credit.isExpired, true);
      });
    });

    group('hasValue', () {
      test('returns true when has remaining pages and not expired', () {
        final credit = Credit(
          id: 'test',
          userId: 'user',
          pagesBw: 5,
          reason: 'Test',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        );

        expect(credit.hasValue, true);
      });

      test('returns false when no remaining pages', () {
        final credit = Credit(
          id: 'test',
          userId: 'user',
          pagesBw: 5,
          pagesBwUsed: 5,
          reason: 'Test',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        );

        expect(credit.hasValue, false);
      });
    });

    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final json = {
          'id': 'credit-123',
          'user_id': 'user-456',
          'pages_bw': 10,
          'pages_color': 5,
          'pages_bw_used': 2,
          'pages_color_used': 1,
          'reason': 'Refund for failed print',
          'source_order_id': 'order-789',
          'expires_at': '2024-02-15T10:30:00Z',
          'created_at': '2024-01-15T10:30:00Z',
        };

        final credit = Credit.fromJson(json);

        expect(credit.id, 'credit-123');
        expect(credit.userId, 'user-456');
        expect(credit.pagesBw, 10);
        expect(credit.pagesColor, 5);
        expect(credit.pagesBwUsed, 2);
        expect(credit.pagesColorUsed, 1);
        expect(credit.reason, 'Refund for failed print');
        expect(credit.sourceOrderId, 'order-789');
      });
    });
  });

  group('CreditSummary', () {
    test('fromCredits calculates totals correctly', () {
      final credits = [
        Credit(
          id: 'c1',
          userId: 'user',
          pagesBw: 5,
          pagesColor: 2,
          pagesBwUsed: 1,
          pagesColorUsed: 0,
          reason: 'Test 1',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
        Credit(
          id: 'c2',
          userId: 'user',
          pagesBw: 3,
          pagesColor: 1,
          pagesBwUsed: 0,
          pagesColorUsed: 0,
          reason: 'Test 2',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
      ];

      final summary = CreditSummary.fromCredits(credits);

      // c1: 4 bw, 2 color; c2: 3 bw, 1 color
      expect(summary.totalBwPages, 7);
      expect(summary.totalColorPages, 3);
      expect(summary.hasCredits, true);
    });

    test('valueInPaise calculates correctly', () {
      final summary = CreditSummary(
        totalBwPages: 10,
        totalColorPages: 5,
        activeCredits: [],
      );

      // (10 * 300) + (5 * 1000) = 3000 + 5000 = 8000
      expect(summary.valueInPaise, 8000);
    });

    test('empty factory creates zero summary', () {
      final summary = CreditSummary.empty();

      expect(summary.totalBwPages, 0);
      expect(summary.totalColorPages, 0);
      expect(summary.hasCredits, false);
      expect(summary.valueInPaise, 0);
    });
  });
}
