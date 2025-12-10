import 'package:json_annotation/json_annotation.dart';
import '../constants/app_constants.dart';

part 'order.g.dart';

/// Model representing a print order
@JsonSerializable()
class PrintOrder {
  final String id;
  @JsonKey(name: 'order_number')
  final int orderNumber;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'society_id')
  final String societyId;
  @JsonKey(name: 'station_id')
  final String stationId;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'file_hash')
  final String? fileHash;
  @JsonKey(name: 'total_pages')
  final int totalPages;
  @JsonKey(name: 'bw_pages')
  final int bwPages;
  @JsonKey(name: 'color_pages')
  final int colorPages;
  final int copies;
  @JsonKey(name: 'amount_paise')
  final int amountPaise;
  @JsonKey(name: 'credits_used_paise')
  final int creditsUsedPaise;
  @JsonKey(name: 'final_amount_paise')
  final int finalAmountPaise;
  @JsonKey(name: 'paytm_order_id')
  final String? paytmOrderId;
  @JsonKey(name: 'paytm_txn_id')
  final String? paytmTxnId;
  @JsonKey(name: 'payment_status')
  final String paymentStatus;
  @JsonKey(name: 'paid_at')
  final DateTime? paidAt;
  @JsonKey(name: 'epson_job_id')
  final String? epsonJobId;
  @JsonKey(name: 'print_status')
  final String printStatus;
  @JsonKey(name: 'print_error_code')
  final String? printErrorCode;
  @JsonKey(name: 'printed_at')
  final DateTime? printedAt;
  @JsonKey(name: 'refund_status')
  final String? refundStatus;
  @JsonKey(name: 'refund_reason')
  final String? refundReason;
  @JsonKey(name: 'refund_type')
  final String? refundType;
  @JsonKey(name: 'paytm_refund_id')
  final String? paytmRefundId;
  @JsonKey(name: 'goodwill_credit_given')
  final bool goodwillCreditGiven;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
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
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrintOrder.fromJson(Map<String, dynamic> json) => _$PrintOrderFromJson(json);
  Map<String, dynamic> toJson() => _$PrintOrderToJson(this);

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

  /// Calculate price for given pages
  static int calculatePrice({
    required int bwPages,
    required int colorPages,
    int copies = 1,
  }) {
    final bwTotal = bwPages * AppConstants.bwPricePerPagePaise;
    final colorTotal = colorPages * AppConstants.colorPricePerPagePaise;
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
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'PrintOrder(id: $id, orderNumber: $orderNumber, status: $printStatus)';
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
