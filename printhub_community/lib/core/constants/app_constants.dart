/// Application-wide constants for PrintHub Community
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ============ APP INFO ============
  static const String appName = 'PrintHub Community';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // ============ SUPABASE ============
  // TODO: Replace with actual Supabase credentials
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';

  // ============ RAZORPAY ============
  // TODO: Replace with actual Razorpay credentials
  static const String razorpayKeyId = 'rzp_test_xxxxxxxxxxxxx';
  static const String razorpayKeySecret = 'your-key-secret';

  // ============ EPSON CONNECT ============
  // TODO: Replace with actual Epson Connect credentials
  static const String epsonClientId = 'your-epson-client-id';
  static const String epsonClientSecret = 'your-epson-client-secret';
  static const String epsonPrinterEmail = 'printer@print.epsonconnect.com';

  // ============ PRICING ============
  static const double pricePerBwPage = 2.0; // ₹2 per B/W page
  static const double pricePerColorPage = 10.0; // ₹10 per color page
  static const double minimumOrderAmount = 2.0; // ₹2 minimum
  static const double platformFeePercentage = 0.0; // No platform fee for MVP
  static const double gstPercentage = 0.0; // GST included in price for MVP

  // ============ FILE LIMITS ============
  static const int maxFileSizeMb = 10; // 10 MB max file size
  static const int maxFileSizeBytes = maxFileSizeMb * 1024 * 1024;
  static const int maxPagesPerJob = 50; // Max 50 pages per job
  static const int maxFilesPerUpload = 5; // Max 5 files per upload
  static const List<String> allowedFileTypes = ['pdf', 'jpg', 'jpeg', 'png'];
  static const List<String> allowedMimeTypes = [
    'application/pdf',
    'image/jpeg',
    'image/jpg',
    'image/png',
  ];

  // ============ TIMING ============
  static const int otpExpiryMinutes = 5;
  static const int otpResendCooldownSeconds = 30;
  static const int printJobExpiryHours = 24; // Jobs expire after 24 hours
  static const int documentRetentionMinutes = 30; // Uncollected docs shredded after 30 min
  static const int paymentTimeoutMinutes = 10;

  // ============ VALIDATION ============
  static const int phoneNumberLength = 10;
  static const int otpLength = 6;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int minFlatNumberLength = 1;
  static const int maxFlatNumberLength = 10;

  // ============ PAGINATION ============
  static const int defaultPageSize = 20;
  static const int historyPageSize = 15;

  // ============ CACHE ============
  static const int cacheExpiryHours = 24;
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String fcmTokenKey = 'fcm_token';

  // ============ ERROR MESSAGES ============
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'No internet connection. Please check your network.';
  static const String sessionExpired = 'Your session has expired. Please login again.';
  static const String fileTooLarge = 'File size exceeds the maximum limit of $maxFileSizeMb MB.';
  static const String invalidFileType = 'Invalid file type. Please upload PDF or image files only.';
  static const String paymentFailed = 'Payment failed. Please try again.';
  static const String printerOffline = 'Printer is currently offline. Please try again later.';
  static const String tooManyPages = 'Maximum $maxPagesPerJob pages allowed per job.';

  // ============ SUCCESS MESSAGES ============
  static const String loginSuccess = 'Welcome to PrintHub Community!';
  static const String logoutSuccess = 'You have been logged out successfully.';
  static const String paymentSuccess = 'Payment successful! Your document is being printed.';
  static const String uploadSuccess = 'Document uploaded successfully.';
  static const String profileUpdateSuccess = 'Profile updated successfully.';

  // ============ SOCIETY INFO (for pilot) ============
  static const String societyId = 'pilot_society_001';
  static const String societyName = 'Sample Residency';
  static const String stationLocation = 'Near Security Gate, Ground Floor';

  // ============ SUPPORT ============
  static const String supportEmail = 'support@printhub.community';
  static const String supportPhone = '+91 98765 43210';
  static const String supportWhatsApp = '+919876543210';
  static const String privacyPolicyUrl = 'https://printhub.community/privacy';
  static const String termsOfServiceUrl = 'https://printhub.community/terms';
  static const String faqUrl = 'https://printhub.community/faq';

  // ============ PRINT STATUS ============
  static const String statusPending = 'pending';
  static const String statusProcessing = 'processing';
  static const String statusPrinting = 'printing';
  static const String statusReady = 'ready';
  static const String statusCollected = 'collected';
  static const String statusExpired = 'expired';
  static const String statusFailed = 'failed';
  static const String statusRefunded = 'refunded';

  // ============ PAYMENT STATUS ============
  static const String paymentPending = 'pending';
  static const String paymentSuccess2 = 'success';
  static const String paymentFailedStatus = 'failed';
  static const String paymentRefundedStatus = 'refunded';
}

/// Print paper types
enum PaperType {
  a4('A4', 'Standard A4 (210 x 297 mm)'),
  letter('Letter', 'US Letter (8.5 x 11 in)');

  const PaperType(this.name, this.description);
  final String name;
  final String description;
}

/// Print color modes
enum ColorMode {
  blackAndWhite('B/W', 'Black & White'),
  color('Color', 'Full Color');

  const ColorMode(this.shortName, this.fullName);
  final String shortName;
  final String fullName;
}

/// Print job status enum
enum PrintJobStatus {
  pending('Pending', 'Waiting for payment'),
  processing('Processing', 'Preparing document'),
  printing('Printing', 'Document is being printed'),
  ready('Ready', 'Ready for pickup'),
  collected('Collected', 'Document collected'),
  expired('Expired', 'Document expired and shredded'),
  failed('Failed', 'Printing failed'),
  refunded('Refunded', 'Payment refunded');

  const PrintJobStatus(this.title, this.description);
  final String title;
  final String description;

  static PrintJobStatus fromString(String status) {
    return PrintJobStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => PrintJobStatus.pending,
    );
  }
}
