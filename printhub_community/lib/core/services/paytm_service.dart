import 'dart:convert';
import 'package:http/http.dart' as http;

import '../logging/app_logger.dart';

/// Service for Paytm payment operations
/// NOTE: All sensitive operations (checksum generation, QR creation) happen server-side
/// This service mainly handles transaction status checks and models
class PaytmService {
  final String supabaseUrl;
  final String supabaseAnonKey;

  final http.Client _client;

  PaytmService({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================
  // Order Creation (via Edge Function)
  // ============================================

  /// Create order via Edge Function
  /// This handles Paytm checksum generation server-side for security
  Future<CreateOrderResponse> createOrder({
    required String userId,
    required String stationId,
    required String fileName,
    String? fileHash,
    required int totalPages,
    required int bwPages,
    required int colorPages,
    required int copies,
    required String authToken,
  }) async {
    final url = '$supabaseUrl/functions/v1/create-order';

    AppLogger.debug('Creating order via Edge Function', tag: 'Paytm');

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode({
          'userId': userId,
          'stationId': stationId,
          'fileName': fileName,
          'fileHash': fileHash,
          'totalPages': totalPages,
          'bwPages': bwPages,
          'colorPages': colorPages,
          'copies': copies,
        }),
      );

      AppLogger.debug('Create order response: ${response.statusCode}', tag: 'Paytm');

      if (response.statusCode != 200) {
        throw PaytmException(
          'Order creation failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true) {
        throw PaytmException(data['error'] ?? 'Order creation failed');
      }

      return CreateOrderResponse.fromJson(data);
    } catch (e) {
      AppLogger.error('Create order error', error: e, tag: 'Paytm');
      rethrow;
    }
  }

  // ============================================
  // Transaction Status (via Edge Function)
  // ============================================

  /// Check transaction status
  /// Note: For MVP, we rely on webhook + Supabase Realtime instead of polling
  Future<PaytmTransactionStatus> getTransactionStatus(String orderId) async {
    // For MVP, transaction status comes via Supabase Realtime subscription
    // This method is a placeholder for future direct status checks if needed
    throw UnimplementedError(
      'Transaction status should come via Supabase Realtime subscription',
    );
  }

  void dispose() {
    _client.close();
  }
}

// ============================================
// Response Models
// ============================================

/// Response from create-order Edge Function
class CreateOrderResponse {
  final bool success;
  final OrderDetails order;
  final QrData? qr;
  final StationInfo station;

  CreateOrderResponse({
    required this.success,
    required this.order,
    this.qr,
    required this.station,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      success: json['success'] as bool,
      order: OrderDetails.fromJson(json['order'] as Map<String, dynamic>),
      qr: json['qr'] != null ? QrData.fromJson(json['qr'] as Map<String, dynamic>) : null,
      station: StationInfo.fromJson(json['station'] as Map<String, dynamic>),
    );
  }
}

class OrderDetails {
  final String id;
  final int? orderNumber;
  final String paytmOrderId;
  final int amountPaise;
  final int creditsUsedPaise;
  final int finalAmountPaise;
  final DateTime expiresAt;
  final String paymentStatus;
  final String printStatus;

  OrderDetails({
    required this.id,
    this.orderNumber,
    required this.paytmOrderId,
    required this.amountPaise,
    required this.creditsUsedPaise,
    required this.finalAmountPaise,
    required this.expiresAt,
    required this.paymentStatus,
    required this.printStatus,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as int?,
      paytmOrderId: json['paytmOrderId'] as String,
      amountPaise: json['amountPaise'] as int,
      creditsUsedPaise: json['creditsUsedPaise'] as int,
      finalAmountPaise: json['finalAmountPaise'] as int,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      paymentStatus: json['paymentStatus'] as String,
      printStatus: json['printStatus'] as String,
    );
  }
}

class QrData {
  final String? qrCodeId;
  final String? qrData;
  final String? qrImage; // Base64 encoded
  final String? deepLink;
  final bool isFree;

  QrData({
    this.qrCodeId,
    this.qrData,
    this.qrImage,
    this.deepLink,
    this.isFree = false,
  });

  factory QrData.fromJson(Map<String, dynamic> json) {
    return QrData(
      qrCodeId: json['qrCodeId'] as String?,
      qrData: json['qrData'] as String?,
      qrImage: json['qrImage'] as String?,
      deepLink: json['deepLink'] as String?,
      isFree: json['isFree'] as bool? ?? false,
    );
  }
}

class StationInfo {
  final String id;
  final String name;
  final String? location;

  StationInfo({
    required this.id,
    required this.name,
    this.location,
  });

  factory StationInfo.fromJson(Map<String, dynamic> json) {
    return StationInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
    );
  }
}

class PaytmTransactionStatus {
  final bool success;
  final String orderId;
  final String? txnId;
  final String status;
  final double? amount;
  final String? paymentMode;
  final DateTime? txnDate;
  final String? resultCode;
  final String? resultMessage;

  PaytmTransactionStatus({
    required this.success,
    required this.orderId,
    this.txnId,
    required this.status,
    this.amount,
    this.paymentMode,
    this.txnDate,
    this.resultCode,
    this.resultMessage,
  });

  bool get isPaid => status == 'TXN_SUCCESS';
  bool get isPending => status == 'PENDING';
  bool get isFailed => status == 'TXN_FAILURE';

  factory PaytmTransactionStatus.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>?;
    final resultInfo = body?['resultInfo'] as Map<String, dynamic>?;
    final status = resultInfo?['resultStatus'] as String? ?? 'UNKNOWN';

    return PaytmTransactionStatus(
      success: status == 'TXN_SUCCESS',
      orderId: body?['orderId'] as String? ?? '',
      txnId: body?['txnId'] as String?,
      status: status,
      amount: double.tryParse(body?['txnAmount']?.toString() ?? ''),
      paymentMode: body?['paymentMode'] as String?,
      txnDate: body?['txnDate'] != null
          ? DateTime.tryParse(body!['txnDate'] as String)
          : null,
      resultCode: resultInfo?['resultCode'] as String?,
      resultMessage: resultInfo?['resultMsg'] as String?,
    );
  }
}

class PaytmRefundResponse {
  final bool success;
  final String orderId;
  final String refundId;
  final String? txnId;
  final double? refundAmount;
  final String? errorMessage;
  final String? resultCode;

  PaytmRefundResponse({
    required this.success,
    required this.orderId,
    required this.refundId,
    this.txnId,
    this.refundAmount,
    this.errorMessage,
    this.resultCode,
  });

  factory PaytmRefundResponse.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>?;
    final resultInfo = body?['resultInfo'] as Map<String, dynamic>?;
    final status = resultInfo?['resultStatus'] as String? ?? 'UNKNOWN';

    return PaytmRefundResponse(
      success: status == 'TXN_SUCCESS' || status == 'PENDING',
      orderId: body?['orderId'] as String? ?? '',
      refundId: body?['refundId'] as String? ?? '',
      txnId: body?['txnId'] as String?,
      refundAmount: double.tryParse(body?['refundAmount']?.toString() ?? ''),
      errorMessage: status != 'TXN_SUCCESS' ? resultInfo?['resultMsg'] as String? : null,
      resultCode: resultInfo?['resultCode'] as String?,
    );
  }
}

// ============================================
// Webhook Payload
// ============================================

class PaytmWebhookPayload {
  final String orderId;
  final String txnId;
  final String status;
  final double amount;
  final String paymentMode;
  final DateTime txnDate;
  final String signature;
  final String mid;

  PaytmWebhookPayload({
    required this.orderId,
    required this.txnId,
    required this.status,
    required this.amount,
    required this.paymentMode,
    required this.txnDate,
    required this.signature,
    required this.mid,
  });

  bool get isSuccess => status == 'TXN_SUCCESS';

  factory PaytmWebhookPayload.fromJson(Map<String, dynamic> json) {
    return PaytmWebhookPayload(
      orderId: json['ORDERID'] as String,
      txnId: json['TXNID'] as String,
      status: json['STATUS'] as String,
      amount: double.parse(json['TXNAMOUNT'] as String),
      paymentMode: json['PAYMENTMODE'] as String? ?? 'UPI',
      txnDate: DateTime.parse(json['TXNDATE'] as String),
      signature: json['CHECKSUMHASH'] as String,
      mid: json['MID'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'ORDERID': orderId,
    'TXNID': txnId,
    'STATUS': status,
    'TXNAMOUNT': amount.toStringAsFixed(2),
    'PAYMENTMODE': paymentMode,
    'TXNDATE': txnDate.toIso8601String(),
    'CHECKSUMHASH': signature,
    'MID': mid,
  };
}

// ============================================
// Exception
// ============================================

class PaytmException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;
  final String? code;

  PaytmException(
    this.message, {
    this.statusCode,
    this.body,
    this.code,
  });

  @override
  String toString() => 'PaytmException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}${code != null ? ' [$code]' : ''}';
}
