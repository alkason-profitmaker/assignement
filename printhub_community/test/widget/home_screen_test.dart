import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printhub_community/core/constants/app_constants.dart';
import 'package:printhub_community/features/home/screens/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('should display app name', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(AppConstants.appName), findsOneWidget);
    });

    testWidgets('should display PRINT NOW button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PRINT NOW'), findsOneWidget);
    });

    testWidgets('should display pricing information', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pricing'), findsOneWidget);
      expect(find.textContaining('₹3/page'), findsOneWidget);
      expect(find.textContaining('₹10/page'), findsOneWidget);
    });

    testWidgets('should display Available Stations section', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Available Stations'), findsOneWidget);
    });

    testWidgets('should navigate to order history on icon tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap history icon
      final historyIcon = find.byIcon(Icons.history);
      expect(historyIcon, findsOneWidget);

      await tester.tap(historyIcon);
      await tester.pumpAndSettle();

      // Should navigate to order history screen
      expect(find.text('Order History'), findsOneWidget);
    });

    testWidgets('should navigate to profile on icon tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap profile icon
      final profileIcon = find.byIcon(Icons.person_outline);
      expect(profileIcon, findsOneWidget);

      await tester.tap(profileIcon);
      await tester.pumpAndSettle();

      // Should navigate to profile screen
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
