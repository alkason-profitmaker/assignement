import '../constants/app_constants.dart';

/// Model representing a print order
class PrintOrder {
  final String id;
  final int orderNumber;
  final String userId;
  final String societyId;
  final String stationId;
  final String fileName;
  final String? fileHash;
  final int totalPages;
  final int bwPages;
  final int colorPages;
  final int copies;
  final int amountPaise;
  final int creditsUsedPaise;
  final int finalAmountPaise;
  final String? paytmOrderId;
  final String? paytmTxnId;
  final String paymentStatus;
  final DateTime? paidAt;
  final String? epsonJobId;
  final String printStatus;
  final String? printErrorCode;
  final DateTime? printedAt;
  final String? refundStatus;
  final String? refundReason;
  final String? refundType;
  final String? paytmRefundId;
  final bool goodwillCreditGiven;
  final String? qrData;
  final String? qrCodeId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrintOrder({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.societyId,
    required this.stationId,
    required this.fileName,
    this.fileHash,
    required this.totalPages,
    required this.bwPages,
    required this.colorPages,
    this.copies = 1,
    required this.amountPaise,
    this.creditsUsedPaise = 0,
    required this.finalAmountPaise,
    this.paytmOrderId,
    this.paytmTxnId,
    this.paymentStatus = 'PENDING',
    this.paidAt,
    this.epsonJobId,
    this.printStatus = 'WAITING',
    this.printErrorCode,
    this.printedAt,
    this.refundStatus,
    this.refundReason,
    this.refundType,
    this.paytmRefundId,
    this.goodwillCreditGiven = false,
    this.qrData,
    this.qrCodeId,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrintOrder.fromJson(Map<String, dynamic> json) {
    return PrintOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as int,
      userId: json['user_id'] as String,
      societyId: json['society_id'] as String,
      stationId: json['station_id'] as String,
      fileName: json['file_name'] as String,
      fileHash: json['file_hash'] as String?,
      totalPages: json['total_pages'] as int,
      bwPages: json['bw_pages'] as int,
      colorPages: json['color_pages'] as int,
      copies: json['copies'] as int? ?? 1,
      amountPaise: json['amount_paise'] as int,
      creditsUsedPaise: json['credits_used_paise'] as int? ?? 0,
      finalAmountPaise: json['final_amount_paise'] as int,
      paytmOrderId: json['paytm_order_id'] as String?,
      paytmTxnId: json['paytm_txn_id'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      epsonJobId: json['epson_job_id'] as String?,
      printStatus: json['print_status'] as String? ?? 'WAITING',
      printErrorCode: json['print_error_code'] as String?,
      printedAt: json['printed_at'] != null
          ? DateTime.parse(json['printed_at'] as String)
          : null,
      refundStatus: json['refund_status'] as String?,
      refundReason: json['refund_reason'] as String?,
      refundType: json['refund_type'] as String?,
      paytmRefundId: json['paytm_refund_id'] as String?,
      goodwillCreditGiven: json['goodwill_credit_given'] as bool? ?? false,
      qrData: json['qr_data'] as String?,
      qrCodeId: json['qr_code_id'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'user_id': userId,
      'society_id': societyId,
      'station_id': stationId,
      'file_name': fileName,
      'file_hash': fileHash,
      'total_pages': totalPages,
      'bw_pages': bwPages,
      'color_pages': colorPages,
      'copies': copies,
      'amount_paise': amountPaise,
      'credits_used_paise': creditsUsedPaise,
      'final_amount_paise': finalAmountPaise,
      'paytm_order_id': paytmOrderId,
      'paytm_txn_id': paytmTxnId,
      'payment_status': paymentStatus,
      'paid_at': paidAt?.toIso8601String(),
      'epson_job_id': epsonJobId,
      'print_status': printStatus,
      'print_error_code': printErrorCode,
      'printed_at': printedAt?.toIso8601String(),
      'refund_status': refundStatus,
      'refund_reason': refundReason,
      'refund_type': refundType,
      'paytm_refund_id': paytmRefundId,
      'goodwill_credit_given': goodwillCreditGiven,
      'qr_data': qrData,
      'qr_code_id': qrCodeId,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Computed properties
  double get amountRupees => amountPaise / 100;
  double get finalAmountRupees => finalAmountPaise / 100;
  double get creditsUsedRupees => creditsUsedPaise / 100;

  PaymentStatus get paymentStatusEnum => PaymentStatus.fromString(paymentStatus);
  PrintStatus get printStatusEnum => PrintStatus.fromString(printStatus);
  RefundType? get refundTypeEnum => RefundType.fromString(refundType);

  bool get isPending => paymentStatus == 'PENDING';
  bool get isPaid => paymentStatus == 'PAID';
  bool get isRefunded => paymentStatus == 'REFUNDED';
  bool get isCompleted => printStatus == 'DONE';
  bool get isFailed => printStatus == 'FAILED';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canBeRefunded => isPaid && !isRefunded && !isCompleted;

  /// Calculate price for given pages using default pricing
  /// For society-specific pricing, use Society.calculatePrice() instead
  static int calculatePrice({
    required int bwPages,
    required int colorPages,
    int copies = 1,
    int? bwPricePerPagePaise,
    int? colorPricePerPagePaise,
  }) {
    final bwPrice = bwPricePerPagePaise ?? AppConstants.defaultBwPricePerPagePaise;
    final colorPrice = colorPricePerPagePaise ?? AppConstants.defaultColorPricePerPagePaise;
    final bwTotal = bwPages * bwPrice;
    final colorTotal = colorPages * colorPrice;
    return (bwTotal + colorTotal) * copies;
  }

  PrintOrder copyWith({
    String? id,
    int? orderNumber,
    String? userId,
    String? societyId,
    String? stationId,
    String? fileName,
    String? fileHash,
    int? totalPages,
    int? bwPages,
    int? colorPages,
    int? copies,
    int? amountPaise,
    int? creditsUsedPaise,
    int? finalAmountPaise,
    String? paytmOrderId,
    String? paytmTxnId,
    String? paymentStatus,
    DateTime? paidAt,
    String? epsonJobId,
    String? printStatus,
    String? printErrorCode,
    DateTime? printedAt,
    String? refundStatus,
    String? refundReason,
    String? refundType,
    String? paytmRefundId,
    bool? goodwillCreditGiven,
    String? qrData,
    String? qrCodeId,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrintOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      societyId: societyId ?? this.societyId,
      stationId: stationId ?? this.stationId,
      fileName: fileName ?? this.fileName,
      fileHash: fileHash ?? this.fileHash,
      totalPages: totalPages ?? this.totalPages,
      bwPages: bwPages ?? this.bwPages,
      colorPages: colorPages ?? this.colorPages,
      copies: copies ?? this.copies,
      amountPaise: amountPaise ?? this.amountPaise,
      creditsUsedPaise: creditsUsedPaise ?? this.creditsUsedPaise,
      finalAmountPaise: finalAmountPaise ?? this.finalAmountPaise,
      paytmOrderId: paytmOrderId ?? this.paytmOrderId,
      paytmTxnId: paytmTxnId ?? this.paytmTxnId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      epsonJobId: epsonJobId ?? this.epsonJobId,
      printStatus: printStatus ?? this.printStatus,
      printErrorCode: printErrorCode ?? this.printErrorCode,
      printedAt: printedAt ?? this.printedAt,
      refundStatus: refundStatus ?? this.refundStatus,
      refundReason: refundReason ?? this.refundReason,
      refundType: refundType ?? this.refundType,
      paytmRefundId: paytmRefundId ?? this.paytmRefundId,
      goodwillCreditGiven: goodwillCreditGiven ?? this.goodwillCreditGiven,
      qrData: qrData ?? this.qrData,
      qrCodeId: qrCodeId ?? this.qrCodeId,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PrintOrder(id: $id, orderNumber: $orderNumber, status: $printStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintOrder && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Request model for creating a new order
class CreateOrderRequest {
  final String stationId;
  final String fileName;
  final String? fileHash;
  final int totalPages;
  final int bwPages;
  final int colorPages;
  final int copies;
  final List<int> fileBytes; // Document bytes for printing

  CreateOrderRequest({
    required this.stationId,
    required this.fileName,
    this.fileHash,
    required this.totalPages,
    required this.bwPages,
    required this.colorPages,
    this.copies = 1,
    required this.fileBytes,
  });

  Map<String, dynamic> toJson() => {
        'station_id': stationId,
        'file_name': fileName,
        'file_hash': fileHash,
        'total_pages': totalPages,
        'bw_pages': bwPages,
        'color_pages': colorPages,
        'copies': copies,
      };
}
