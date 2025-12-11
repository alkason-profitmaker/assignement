import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';

/// Service for monitoring payment status via Supabase Realtime
/// Payment confirmation comes from Paytm webhook -> Edge Function -> DB update
/// This service listens for those DB updates and notifies the mobile app
class PaymentCallbackService {
  final SupabaseClient _supabase;

  StreamController<PaymentStatusUpdate>? _statusController;
  RealtimeChannel? _orderChannel;
  String? _currentOrderId;

  PaymentCallbackService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  /// Stream of payment status updates
  Stream<PaymentStatusUpdate> get statusUpdates {
    _statusController ??= StreamController<PaymentStatusUpdate>.broadcast();
    return _statusController!.stream;
  }

  /// Start monitoring payment for an order via Supabase Realtime
  void startPaymentMonitoring(String orderId) {
    AppLogger.info('Starting payment monitoring for order: $orderId', tag: 'Payment');

    _currentOrderId = orderId;
    _stopMonitoring();

    // Subscribe to real-time updates from Supabase
    // When webhook confirms payment, it updates the orders table
    // This subscription catches that update and notifies the mobile app
    _orderChannel = _supabase
        .channel('order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            _handleOrderUpdate(payload.newRecord);
          },
        )
        .subscribe();

    // Also do initial check in case payment was already confirmed
    _checkCurrentStatus(orderId);
  }

  /// Stop monitoring payment
  void stopPaymentMonitoring() {
    AppLogger.debug('Stopping payment monitoring', tag: 'Payment');
    _stopMonitoring();
    _currentOrderId = null;
  }

  void _stopMonitoring() {
    _orderChannel?.unsubscribe();
    _orderChannel = null;
  }

  /// Handle order update from Realtime subscription
  void _handleOrderUpdate(Map<String, dynamic> orderData) {
    final orderId = orderData['id'] as String?;
    if (orderId != _currentOrderId) return;

    final paymentStatus = orderData['payment_status'] as String?;
    final printStatus = orderData['print_status'] as String?;

    if (paymentStatus?.toUpperCase() == 'PAID') {
      AppLogger.info('Payment confirmed via Realtime for order: $orderId', tag: 'Payment');

      _statusController?.add(PaymentStatusUpdate(
        orderId: orderId!,
        status: PaymentCallbackStatus.success,
        txnId: orderData['paytm_txn_id'] as String?,
        message: 'Payment confirmed',
      ));
    } else if (printStatus?.toUpperCase() == 'FAILED') {
      AppLogger.warning('Print failed for order: $orderId', tag: 'Payment');

      _statusController?.add(PaymentStatusUpdate(
        orderId: orderId!,
        status: PaymentCallbackStatus.failed,
        message: orderData['print_error_code'] as String? ?? 'Print failed',
      ));
    }
  }

  /// Check current order status (for cases where payment was already confirmed)
  Future<void> _checkCurrentStatus(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id, payment_status, paytm_txn_id, print_status, print_error_code')
          .eq('id', orderId)
          .single();

      _handleOrderUpdate(response);
    } catch (e) {
      AppLogger.warning('Initial status check failed', error: e, tag: 'Payment');
    }
  }

  void dispose() {
    _stopMonitoring();
    _statusController?.close();
    _statusController = null;
  }
}

/// Payment status update event
class PaymentStatusUpdate {
  final String orderId;
  final PaymentCallbackStatus status;
  final String? txnId;
  final String? message;
  final String? errorCode;

  PaymentStatusUpdate({
    required this.orderId,
    required this.status,
    this.txnId,
    this.message,
    this.errorCode,
  });
}

/// Payment callback status enum (distinct from model PaymentStatus)
enum PaymentCallbackStatus {
  pending,
  success,
  failed,
  cancelled,
  refunded,
}

/// Result of webhook processing
class WebhookProcessResult {
  final bool success;
  final String? orderId;
  final String? error;
  final WebhookResultType type;

  WebhookProcessResult._({
    required this.success,
    required this.type,
    this.orderId,
    this.error,
  });

  factory WebhookProcessResult.success(String orderId) {
    return WebhookProcessResult._(
      success: true,
      type: WebhookResultType.success,
      orderId: orderId,
    );
  }

  factory WebhookProcessResult.invalidSignature() {
    return WebhookProcessResult._(
      success: false,
      type: WebhookResultType.invalidSignature,
      error: 'Invalid webhook signature',
    );
  }

  factory WebhookProcessResult.paymentFailed(String orderId) {
    return WebhookProcessResult._(
      success: false,
      type: WebhookResultType.paymentFailed,
      orderId: orderId,
      error: 'Payment was declined',
    );
  }

  factory WebhookProcessResult.error(String message) {
    return WebhookProcessResult._(
      success: false,
      type: WebhookResultType.processingError,
      error: message,
    );
  }
}

enum WebhookResultType {
  success,
  invalidSignature,
  paymentFailed,
  processingError,
}
