import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../constants/supabase_constants.dart';

/// Service for Paytm Dynamic QR and payment operations
/// Note: Actual payment is done via Soundbox, this handles QR generation and webhooks
class PaytmService {
  final String merchantId;
  final String merchantKey;
  final bool isProduction;

  PaytmService({
    required this.merchantId,
    required this.merchantKey,
    this.isProduction = false,
  });

  String get _baseUrl =>
      isProduction ? ApiEndpoints.paytmBaseUrl : ApiEndpoints.paytmStagingUrl;

  // ============================================
  // QR Code Generation
  // ============================================

  /// Generate Dynamic QR code for order
  /// Returns QR code data that can be displayed or used with Soundbox
  Future<PaytmQrResponse> generateDynamicQr({
    required String orderId,
    required double amount,
    String? posId,
  }) async {
    final url = '$_baseUrl${ApiEndpoints.generateQrEndpoint}';

    final body = {
      'mid': merchantId,
      'orderId': orderId,
      'amount': amount.toStringAsFixed(2),
      'businessType': 'UPI_QR_CODE',
      if (posId != null) 'posId': posId,
    };

    // Generate checksum
    final checksum = _generateChecksum(body);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $merchantKey',
      },
      body: jsonEncode({
        ...body,
        'signature': checksum,
      }),
    );

    if (response.statusCode != 200) {
      throw PaytmException(
        'QR generation failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    return PaytmQrResponse.fromJson(data);
  }

  // ============================================
  // Transaction Status
  // ============================================

  /// Check transaction status
  Future<PaytmTransactionStatus> getTransactionStatus(String orderId) async {
    final url = '$_baseUrl${ApiEndpoints.txnStatusEndpoint}';

    final body = {
      'mid': merchantId,
      'orderId': orderId,
    };

    final checksum = _generateChecksum(body);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        ...body,
        'signature': checksum,
      }),
    );

    if (response.statusCode != 200) {
      throw PaytmException(
        'Status check failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    return PaytmTransactionStatus.fromJson(data);
  }

  // ============================================
  // Refund Processing
  // ============================================

  /// Initiate refund for a transaction
  Future<PaytmRefundResponse> initiateRefund({
    required String orderId,
    required String txnId,
    required String refundId,
    required double amount,
  }) async {
    final url = '$_baseUrl${ApiEndpoints.refundEndpoint}';

    final body = {
      'mid': merchantId,
      'orderId': orderId,
      'txnId': txnId,
      'refId': refundId,
      'refundAmount': amount.toStringAsFixed(2),
    };

    final checksum = _generateChecksum(body);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        ...body,
        'signature': checksum,
      }),
    );

    if (response.statusCode != 200) {
      throw PaytmException(
        'Refund failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    return PaytmRefundResponse.fromJson(data);
  }

  // ============================================
  // Webhook Verification
  // ============================================

  /// Verify webhook signature from Paytm
  bool verifyWebhookSignature(Map<String, dynamic> payload, String signature) {
    final calculatedSignature = _generateChecksum(payload);
    return calculatedSignature == signature;
  }

  // ============================================
  // Checksum Generation
  // ============================================

  String _generateChecksum(Map<String, dynamic> params) {
    // Sort parameters alphabetically
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${params[k]}').join('|');

    // Generate HMAC-SHA256
    final key = utf8.encode(merchantKey);
    final bytes = utf8.encode(paramString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return base64.encode(digest.bytes);
  }
}

// ============================================
// Response Models
// ============================================

class PaytmQrResponse {
  final bool success;
  final String? qrCodeId;
  final String? qrData;
  final String? imageBase64;
  final String? errorMessage;

  PaytmQrResponse({
    required this.success,
    this.qrCodeId,
    this.qrData,
    this.imageBase64,
    this.errorMessage,
  });

  factory PaytmQrResponse.fromJson(Map<String, dynamic> json) {
    final resultCode = json['resultCode'] as String?;
    final success = resultCode == '0000';

    return PaytmQrResponse(
      success: success,
      qrCodeId: json['qrCodeId'] as String?,
      qrData: json['qrData'] as String?,
      imageBase64: json['image'] as String?,
      errorMessage: success ? null : json['resultMsg'] as String?,
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

  PaytmTransactionStatus({
    required this.success,
    required this.orderId,
    this.txnId,
    required this.status,
    this.amount,
    this.paymentMode,
    this.txnDate,
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

  PaytmRefundResponse({
    required this.success,
    required this.orderId,
    required this.refundId,
    this.txnId,
    this.refundAmount,
    this.errorMessage,
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

  PaytmWebhookPayload({
    required this.orderId,
    required this.txnId,
    required this.status,
    required this.amount,
    required this.paymentMode,
    required this.txnDate,
    required this.signature,
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
    );
  }
}

// ============================================
// Exception
// ============================================

class PaytmException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  PaytmException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'PaytmException: $message (status: $statusCode)';
}
