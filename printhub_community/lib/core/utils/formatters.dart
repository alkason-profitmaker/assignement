import 'package:intl/intl.dart';

/// Formatting utilities for PrintHub Community

class Formatters {
  Formatters._();

  /// Format phone number for display
  static String formatPhone(String phone) {
    if (phone.length != 10) return phone;
    return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  /// Format amount in paise to rupees string
  static String formatAmount(int paise) {
    final rupees = paise / 100;
    if (rupees == rupees.roundToDouble()) {
      return '₹${rupees.toInt()}';
    }
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Format amount with detailed breakdown
  static String formatAmountDetailed(int paise) {
    final rupees = paise / 100;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: rupees == rupees.roundToDouble() ? 0 : 2,
    ).format(rupees);
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat.jm().format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('MMM d, h:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    }
  }

  /// Format relative time
  static String formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  /// Format duration for countdown
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Format page count
  static String formatPageCount(int pages) {
    return pages == 1 ? '1 page' : '$pages pages';
  }

  /// Format copy count
  static String formatCopyCount(int copies) {
    return copies == 1 ? '1 copy' : '$copies copies';
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
