/// Supabase table and bucket names
/// These are constant across all environments
class SupabaseConstants {
  SupabaseConstants._();

  // Table Names
  static const String societiesTable = 'societies';
  static const String stationsTable = 'stations';
  static const String usersTable = 'users';
  static const String ordersTable = 'orders';
  static const String creditsTable = 'credits';
  static const String printJobQueueTable = 'print_job_queue';

  // Edge Function Names
  static const String paytmWebhookFunction = 'paytm-webhook';
  static const String epsonStatusFunction = 'epson-status';
  static const String createOrderFunction = 'create-order';
  static const String processRefundFunction = 'process-refund';
  static const String checkPrintStatusFunction = 'check-print-status';

  // Storage Buckets
  static const String documentsBucket = 'documents';
  static const String avatarsBucket = 'avatars';

  // Realtime Channels
  static const String ordersChannel = 'orders-updates';
  static const String stationsChannel = 'stations-status';
}

/// API endpoint paths (not full URLs - those come from environment config)
class ApiEndpoints {
  ApiEndpoints._();

  // Paytm API Endpoints
  static const String generateQrEndpoint = '/theia/api/v1/generateQRCode';
  static const String refundEndpoint = '/refund/apply';
  static const String txnStatusEndpoint = '/v3/order/status';
  static const String initiateTransactionEndpoint = '/theia/api/v1/initiateTransaction';

  // Epson Connect API Endpoints
  static const String epsonAuthEndpoint = '/api/1/printing/oauth2/token';
  static const String epsonPrintersEndpoint = '/api/1/printing/printers';
  static const String epsonJobsEndpoint = '/api/1/printing/printers/{deviceId}/jobs';
  static const String epsonPrintEndpoint = '/api/1/printing/printers/{deviceId}/jobs/{jobId}/print';
}
