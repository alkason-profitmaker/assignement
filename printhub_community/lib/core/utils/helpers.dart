import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Utility class with helper functions
class AppHelpers {
  AppHelpers._();

  // ============ FORMATTING ============

  /// Format phone number for display (e.g., +91 98765 43210)
  static String formatPhoneNumber(String phone) {
    if (phone.length != 10) return phone;
    return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  /// Format currency (e.g., ₹12.00)
  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  /// Format currency without decimals (e.g., ₹12)
  static String formatCurrencyShort(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Format date (e.g., Dec 4, 2025)
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Format date and time (e.g., Dec 4, 2025 at 2:30 PM)
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(date);
  }

  /// Format time (e.g., 2:30 PM)
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// Format relative time (e.g., "2 minutes ago")
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return formatDate(date);
    }
  }

  /// Format file size (e.g., 2.5 MB)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // ============ VALIDATION ============

  /// Validate phone number (10 digits)
  static bool isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.length == AppConstants.phoneNumberLength;
  }

  /// Validate OTP (6 digits)
  static bool isValidOtp(String otp) {
    return otp.length == AppConstants.otpLength &&
        RegExp(r'^\d+$').hasMatch(otp);
  }

  /// Validate name
  static bool isValidName(String name) {
    return name.length >= AppConstants.minNameLength &&
        name.length <= AppConstants.maxNameLength &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(name);
  }

  /// Validate flat number
  static bool isValidFlatNumber(String flat) {
    return flat.length >= AppConstants.minFlatNumberLength &&
        flat.length <= AppConstants.maxFlatNumberLength;
  }

  /// Check if file type is allowed
  static bool isAllowedFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return AppConstants.allowedFileTypes.contains(extension);
  }

  /// Check if file size is within limit
  static bool isFileSizeValid(int bytes) {
    return bytes <= AppConstants.maxFileSizeBytes;
  }

  // ============ CALCULATIONS ============

  /// Calculate print cost
  static double calculatePrintCost({
    required int bwPages,
    required int colorPages,
  }) {
    return (bwPages * AppConstants.pricePerBwPage) +
        (colorPages * AppConstants.pricePerColorPage);
  }

  /// Generate pickup code (6 alphanumeric characters)
  static String generatePickupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();

    for (var i = 0; i < 6; i++) {
      final index = (random + i * 17) % chars.length;
      code.write(chars[index]);
    }

    return code.toString();
  }

  // ============ UI HELPERS ============

  /// Show snackbar message
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, isError: true);
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message ?? 'Please wait...'),
            ],
          ),
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ============ DATE HELPERS ============

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  // ============ STATUS HELPERS ============

  /// Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'printing':
        return Colors.indigo;
      case 'ready':
        return Colors.green;
      case 'collected':
        return Colors.grey;
      case 'expired':
        return Colors.red.shade300;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'processing':
        return Icons.settings;
      case 'printing':
        return Icons.print;
      case 'ready':
        return Icons.check_circle;
      case 'collected':
        return Icons.done_all;
      case 'expired':
        return Icons.timer_off;
      case 'failed':
        return Icons.error;
      case 'refunded':
        return Icons.replay;
      default:
        return Icons.info;
    }
  }
}
