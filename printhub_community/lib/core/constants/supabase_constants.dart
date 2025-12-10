/// Supabase configuration constants
/// IMPORTANT: Replace these with your actual Supabase project credentials
class SupabaseConstants {
  SupabaseConstants._();

  // Supabase Project Configuration
  // TODO: Replace with your Supabase project URL
  static const String projectUrl = 'https://your-project-id.supabase.co';

  // TODO: Replace with your Supabase anon key
  static const String anonKey = 'your-anon-key-here';

  // Table Names
  static const String societiesTable = 'societies';
  static const String stationsTable = 'stations';
  static const String usersTable = 'users';
  static const String ordersTable = 'orders';
  static const String creditsTable = 'credits';

  // Edge Function Names
  static const String paytmWebhookFunction = 'paytm-webhook';
  static const String epsonStatusFunction = 'epson-status';
  static const String createOrderFunction = 'create-order';
  static const String processRefundFunction = 'process-refund';

  // Storage Buckets (if needed in future)
  static const String documentsBucket = 'documents';
  static const String avatarsBucket = 'avatars';

  // Realtime Channels
  static const String ordersChannel = 'orders-updates';
  static const String stationsChannel = 'stations-status';
}

/// API endpoints for external services
class ApiEndpoints {
  ApiEndpoints._();

  // Paytm APIs
  static const String paytmBaseUrl = 'https://securegw.paytm.in';
  static const String paytmStagingUrl = 'https://securegw-stage.paytm.in';
  static const String generateQrEndpoint = '/theia/api/v1/generateQRCode';
  static const String refundEndpoint = '/refund/apply';
  static const String txnStatusEndpoint = '/v3/order/status';

  // Epson Connect APIs
  static const String epsonBaseUrl = 'https://api.epsonconnect.com';
  static const String epsonAuthEndpoint = '/api/1/printing/oauth2/auth/token';
  static const String epsonPrintEndpoint = '/api/1/printing/printers';
  static const String epsonJobStatusEndpoint = '/api/1/printing/jobs';
}
