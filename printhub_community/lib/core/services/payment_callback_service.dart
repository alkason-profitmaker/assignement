import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';
import '../models/order.dart';
import 'paytm_service.dart';

/// Service for handling payment callbacks and status polling
class PaymentCallbackService {
  final PaytmService _paytmService;
  final SupabaseClient _supabase;

  Timer? _pollingTimer;
  StreamController<PaymentStatusUpdate>? _statusController;
  String? _currentOrderId;

  PaymentCallbackService({
    required PaytmService paytmService,
    required SupabaseClient supabase,
  })  : _paytmService = paytmService,
        _supabase = supabase;

  /// Stream of payment status updates
  Stream<PaymentStatusUpdate> get statusUpdates {
    _statusController ??= StreamController<PaymentStatusUpdate>.broadcast();
    return _statusController!.stream;
  }

  /// Start monitoring payment for an order
  void startPaymentMonitoring(String orderId) {
    AppLogger.info('Starting payment monitoring for order: $orderId', tag: 'Payment');

    _currentOrderId = orderId;
    _stopPolling();

    // Poll every 3 seconds for payment status
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPaymentStatus(orderId);
    });

    // Also subscribe to real-time updates from Supabase
    _subscribeToRealtimeUpdates(orderId);
  }

  /// Stop monitoring payment
  void stopPaymentMonitoring() {
    AppLogger.debug('Stopping payment monitoring', tag: 'Payment');
    _stopPolling();
    _currentOrderId = null;
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Check payment status with Paytm API
  Future<void> _checkPaymentStatus(String orderId) async {
    try {
      final status = await _paytmService.getTransactionStatus(orderId);

      if (status.isPaid) {
        AppLogger.info('Payment confirmed for order: $orderId', tag: 'Payment');
        _stopPolling();

        // Update order in database
        await _updateOrderPaymentStatus(
          orderId: orderId,
          txnId: status.txnId ?? '',
          amount: status.amount ?? 0,
          paymentMode: status.paymentMode ?? 'UPI',
        );

        _statusController?.add(PaymentStatusUpdate(
          orderId: orderId,
          status: PaymentCallbackStatus.success,
          txnId: status.txnId,
          message: 'Payment successful',
        ));
      } else if (status.isFailed) {
        AppLogger.warning('Payment failed for order: $orderId', tag: 'Payment');
        _stopPolling();

        _statusController?.add(PaymentStatusUpdate(
          orderId: orderId,
          status: PaymentCallbackStatus.failed,
          message: status.resultMessage ?? 'Payment failed',
          errorCode: status.resultCode,
        ));
      }
      // If pending, continue polling
    } catch (e) {
      AppLogger.warning('Payment status check failed', error: e, tag: 'Payment');
      // Don't stop polling on transient errors
    }
  }

  /// Subscribe to real-time updates from Supabase
  void _subscribeToRealtimeUpdates(String orderId) {
    _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .listen((List<Map<String, dynamic>> data) {
      if (data.isEmpty) return;

      final orderData = data.first;
      final paymentStatus = orderData['payment_status'] as String?;

      if (paymentStatus?.toUpperCase() == 'PAID') {
        _stopPolling();
        _statusController?.add(PaymentStatusUpdate(
          orderId: orderId,
          status: PaymentCallbackStatus.success,
          txnId: orderData['paytm_txn_id'] as String?,
          message: 'Payment confirmed',
        ));
      }
    });
  }

  /// Update order payment status in database
  Future<void> _updateOrderPaymentStatus({
    required String orderId,
    required String txnId,
  }) async {
    try {
      await _supabase.from('orders').update({
        'payment_status': 'PAID',
        'paytm_txn_id': txnId,
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      AppLogger.info('Order payment status updated: $orderId', tag: 'Payment');
    } catch (e) {
      AppLogger.error('Failed to update order payment status', error: e, tag: 'Payment');
      rethrow;
    }
  }

  /// Process webhook callback from Paytm (called from server-side)
  Future<WebhookProcessResult> processWebhook(Map<String, dynamic> payload) async {
    try {
      final webhookData = PaytmWebhookPayload.fromJson(payload);

      // Verify signature
      final isValid = _paytmService.verifyWebhookSignature(
        payload,
        webhookData.signature,
      );

      if (!isValid) {
        AppLogger.warning('Invalid webhook signature', tag: 'Payment');
        return WebhookProcessResult.invalidSignature();
      }

      // Process based on status
      if (webhookData.isSuccess) {
        await _updateOrderPaymentStatus(
          orderId: webhookData.orderId,
          txnId: webhookData.txnId,
        );

        // Notify listeners
        _statusController?.add(PaymentStatusUpdate(
          orderId: webhookData.orderId,
          status: PaymentCallbackStatus.success,
          txnId: webhookData.txnId,
          message: 'Payment successful via webhook',
        ));

        return WebhookProcessResult.success(webhookData.orderId);
      } else {
        // Payment failed - order remains PENDING, will expire naturally
        // No need to update DB - just notify listeners
        _statusController?.add(PaymentStatusUpdate(
          orderId: webhookData.orderId,
          status: PaymentCallbackStatus.failed,
          message: 'Payment failed',
        ));

        return WebhookProcessResult.paymentFailed(webhookData.orderId);
      }
    } catch (e) {
      AppLogger.error('Webhook processing error', error: e, tag: 'Payment');
      return WebhookProcessResult.error(e.toString());
    }
  }

  /// Manually verify and sync payment status for an order
  Future<bool> verifyAndSyncPayment(String orderId) async {
    try {
      final status = await _paytmService.getTransactionStatus(orderId);

      if (status.isPaid) {
        await _updateOrderPaymentStatus(
          orderId: orderId,
          txnId: status.txnId ?? '',
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Payment verification failed', error: e, tag: 'Payment');
      return false;
    }
  }

  void dispose() {
    _stopPolling();
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
