import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../constants/supabase_constants.dart';
import '../logging/app_logger.dart';

/// Service for Paytm Dynamic QR and payment operations
/// Handles QR generation for Soundbox payments and refund processing
class PaytmService {
  final String merchantId;
  final String merchantKey;
  final String website;
  final String industryType;
  final String channelId;
  final String baseUrl;

  final http.Client _client;

  PaytmService({
    required this.merchantId,
    required this.merchantKey,
    required this.website,
    required this.industryType,
    required this.channelId,
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

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
    final url = '$baseUrl${ApiEndpoints.generateQrEndpoint}';

    AppLogger.debug('Generating Paytm QR for order: $orderId, amount: $amount', tag: 'Paytm');

    final body = {
      'mid': merchantId,
      'orderId': orderId,
      'amount': amount.toStringAsFixed(2),
      'businessType': 'UPI_QR_CODE',
      if (posId != null) 'posId': posId,
    };

    // Generate checksum for request body
    final checksum = _generateChecksum(body);

    final requestBody = {
      'body': body,
      'head': {
        'signature': checksum,
      }
    };

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      AppLogger.debug('Paytm QR response: ${response.statusCode}', tag: 'Paytm');

      if (response.statusCode != 200) {
        throw PaytmException(
          'QR generation failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = PaytmQrResponse.fromJson(data);

      if (!result.success) {
        throw PaytmException(result.errorMessage ?? 'QR generation failed');
      }

      return result;
    } catch (e) {
      AppLogger.error('Paytm QR generation error', error: e, tag: 'Paytm');
      rethrow;
    }
  }

  // ============================================
  // Transaction Status
  // ============================================

  /// Check transaction status
  Future<PaytmTransactionStatus> getTransactionStatus(String orderId) async {
    final url = '$baseUrl${ApiEndpoints.txnStatusEndpoint}';

    AppLogger.debug('Checking transaction status for: $orderId', tag: 'Paytm');

    final body = {
      'mid': merchantId,
      'orderId': orderId,
    };

    final checksum = _generateChecksum(body);

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'body': body,
          'head': {
            'signature': checksum,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw PaytmException(
          'Status check failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PaytmTransactionStatus.fromJson(data);
    } catch (e) {
      AppLogger.error('Paytm status check error', error: e, tag: 'Paytm');
      rethrow;
    }
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
    final url = '$baseUrl${ApiEndpoints.refundEndpoint}';

    AppLogger.info('Initiating refund for order: $orderId, amount: $amount', tag: 'Paytm');

    final body = {
      'mid': merchantId,
      'txnType': 'REFUND',
      'orderId': orderId,
      'txnId': txnId,
      'refId': refundId,
      'refundAmount': amount.toStringAsFixed(2),
    };

    final checksum = _generateChecksum(body);

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'body': body,
          'head': {
            'signature': checksum,
          }
        }),
      );

      AppLogger.debug('Paytm refund response: ${response.statusCode}', tag: 'Paytm');

      if (response.statusCode != 200) {
        throw PaytmException(
          'Refund failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = PaytmRefundResponse.fromJson(data);

      if (!result.success) {
        throw PaytmException(result.errorMessage ?? 'Refund failed');
      }

      AppLogger.info('Refund successful for order: $orderId', tag: 'Paytm');
      return result;
    } catch (e) {
      AppLogger.error('Paytm refund error', error: e, tag: 'Paytm');
      rethrow;
    }
  }

  // ============================================
  // Webhook Verification
  // ============================================

  /// Verify webhook signature from Paytm
  bool verifyWebhookSignature(Map<String, dynamic> payload, String signature) {
    try {
      // For webhook verification, exclude the checksum field
      final params = Map<String, dynamic>.from(payload)
        ..remove('CHECKSUMHASH');

      final calculatedSignature = _generateChecksum(params);
      final isValid = calculatedSignature == signature;

      if (!isValid) {
        AppLogger.warning('Webhook signature mismatch', tag: 'Paytm');
      }

      return isValid;
    } catch (e) {
      AppLogger.error('Webhook verification error', error: e, tag: 'Paytm');
      return false;
    }
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

  void dispose() {
    _client.close();
  }
}

// ============================================
// Response Models
// ============================================

class PaytmQrResponse {
  final bool success;
  final String? qrCodeId;
  final String? qrString;
  final String? paytmOrderId;
  final String? qrData;
  final String? imageBase64;
  final String? errorMessage;
  final String? errorCode;

  PaytmQrResponse({
    required this.success,
    this.qrCodeId,
    this.qrString,
    this.paytmOrderId,
    this.qrData,
    this.imageBase64,
    this.errorMessage,
    this.errorCode,
  });

  factory PaytmQrResponse.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>?;
    final resultInfo = body?['resultInfo'] as Map<String, dynamic>?;
    final resultCode = resultInfo?['resultCode'] as String?;
    final success = resultCode == '0000' || resultCode == 'SUCCESS';

    return PaytmQrResponse(
      success: success,
      qrCodeId: body?['qrCodeId'] as String?,
      qrString: body?['qrData'] as String?,
      paytmOrderId: body?['orderId'] as String?,
      qrData: body?['qrData'] as String?,
      imageBase64: body?['image'] as String?,
      errorMessage: success ? null : resultInfo?['resultMsg'] as String?,
      errorCode: success ? null : resultCode,
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
