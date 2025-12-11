import 'package:flutter/material.dart';

/// Application-wide constants for PrintHub Community
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'PrintHub Community';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Print Anytime, Anywhere in Your Society';

  // Colors
  static const Color primaryColor = Color(0xFF2563EB); // Blue
  static const Color secondaryColor = Color(0xFF10B981); // Green
  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF22C55E); // Green
  static const Color warningColor = Color(0xFFF97316); // Orange
  static const Color backgroundColor = Color(0xFFF8FAFC); // Light gray
  static const Color surfaceColor = Color(0xFFFFFFFF); // White
  static const Color textPrimaryColor = Color(0xFF1E293B); // Dark slate
  static const Color textSecondaryColor = Color(0xFF64748B); // Slate

  // Default Pricing (in paise - 100 paise = 1 rupee)
  // These can be overridden per-society in the database
  static const int defaultBwPricePerPagePaise = 300; // ₹3/page B/W
  static const int defaultColorPricePerPagePaise = 1000; // ₹10/page color
  static const int defaultBwCostPerPagePaise = 45; // ₹0.45 cost
  static const int defaultColorCostPerPagePaise = 69; // ₹0.69 cost

  // Legacy aliases for backwards compatibility
  @Deprecated('Use Society.bwPricePerPagePaise or defaultBwPricePerPagePaise')
  static const int bwPricePerPagePaise = defaultBwPricePerPagePaise;
  @Deprecated('Use Society.colorPricePerPagePaise or defaultColorPricePerPagePaise')
  static const int colorPricePerPagePaise = defaultColorPricePerPagePaise;

  // Order Settings
  static const int maxPagesPerOrder = 50;
  static const int maxFileSizeMB = 25;
  static const int orderExpiryMinutes = 120; // 2 hours
  static const int maxCopies = 10;

  // Credit Settings
  static const int creditExpiryDays = 90;
  static const int goodwillCreditPages = 1; // 1 free page on failure

  // Timeouts
  static const int printJobTimeoutSeconds = 300; // 5 minutes
  static const int paymentTimeoutSeconds = 600; // 10 minutes
  static const int apiTimeoutSeconds = 30;

  // File Types
  static const List<String> supportedFileTypes = ['pdf', 'jpg', 'jpeg', 'png'];
  static const List<String> supportedMimeTypes = [
    'application/pdf',
    'image/jpeg',
    'image/png',
  ];

  // Revenue Share
  static const double defaultSocietyCommissionPercent = 40.0;
  static const double printhubCommissionPercent = 60.0;

  // Pagination
  static const int defaultPageSize = 20;
  static const int orderHistoryPageSize = 10;

  // Validation
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 10;
  static const int otpLength = 6;
  static const int otpExpirySeconds = 300; // 5 minutes

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 350);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}

/// Print status enum with user-friendly labels
enum PrintStatus {
  waiting('WAITING', 'Waiting for Payment'),
  awaitingDevice('AWAITING_DEVICE', 'Payment Confirmed'),
  queued('QUEUED', 'In Print Queue'),
  printing('PRINTING', 'Printing...'),
  done('DONE', 'Completed'),
  failed('FAILED', 'Print Failed');

  final String value;
  final String label;
  const PrintStatus(this.value, this.label);

  static PrintStatus fromString(String value) {
    return PrintStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrintStatus.waiting,
    );
  }
}

/// Payment status enum
enum PaymentStatus {
  pending('PENDING', 'Pending Payment'),
  paid('PAID', 'Paid'),
  refunded('REFUNDED', 'Refunded');

  final String value;
  final String label;
  const PaymentStatus(this.value, this.label);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Refund type enum
enum RefundType {
  auto('AUTO', 'Automatic Refund'),
  goodFaith('GOOD_FAITH', 'Good Faith Refund');

  final String value;
  final String label;
  const RefundType(this.value, this.label);

  static RefundType? fromString(String? value) {
    if (value == null) return null;
    return RefundType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RefundType.auto,
    );
  }
}

/// Alert type for system notifications
enum AlertType {
  printerOffline('PRINTER_OFFLINE'),
  outOfPaper('OUT_OF_PAPER'),
  outOfInk('OUT_OF_INK'),
  paperJam('PAPER_JAM'),
  printFailed('PRINT_FAILED'),
  jobTimeout('JOB_TIMEOUT'),
  lowInk('LOW_INK'),
  lowPaper('LOW_PAPER');

  final String value;
  const AlertType(this.value);
}
