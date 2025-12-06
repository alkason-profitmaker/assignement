import '../../domain/entities/print_job_entity.dart';
import '../../../../core/constants/app_constants.dart';

/// Print job data model for API/database operations
class PrintJobModel extends PrintJobEntity {
  const PrintJobModel({
    required super.id,
    required super.userId,
    required super.fileName,
    required super.fileUrl,
    required super.fileSizeBytes,
    required super.mimeType,
    required super.totalPages,
    super.bwPages,
    super.colorPages,
    required super.colorMode,
    super.copies,
    required super.totalAmount,
    required super.status,
    super.pickupCode,
    required super.createdAt,
    super.paymentAt,
    super.printingStartedAt,
    super.readyAt,
    super.collectedAt,
    super.expiredAt,
    super.errorMessage,
  });

  /// Create PrintJobModel from JSON
  factory PrintJobModel.fromJson(Map<String, dynamic> json) {
    return PrintJobModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      mimeType: json['mime_type'] as String,
      totalPages: json['total_pages'] as int,
      bwPages: json['bw_pages'] as int? ?? 0,
      colorPages: json['color_pages'] as int? ?? 0,
      colorMode: json['color_mode'] as String? ?? 'bw',
      copies: json['copies'] as int? ?? 1,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: PrintJobStatus.fromString(json['status'] as String? ?? 'pending'),
      pickupCode: json['pickup_code'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      paymentAt: json['payment_at'] != null
          ? DateTime.parse(json['payment_at'] as String)
          : null,
      printingStartedAt: json['printing_started_at'] != null
          ? DateTime.parse(json['printing_started_at'] as String)
          : null,
      readyAt: json['ready_at'] != null
          ? DateTime.parse(json['ready_at'] as String)
          : null,
      collectedAt: json['collected_at'] != null
          ? DateTime.parse(json['collected_at'] as String)
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Convert PrintJobModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'total_pages': totalPages,
      'bw_pages': bwPages,
      'color_pages': colorPages,
      'color_mode': colorMode,
      'copies': copies,
      'total_amount': totalAmount,
      'status': status.name,
      'pickup_code': pickupCode,
      'created_at': createdAt.toIso8601String(),
      'payment_at': paymentAt?.toIso8601String(),
      'printing_started_at': printingStartedAt?.toIso8601String(),
      'ready_at': readyAt?.toIso8601String(),
      'collected_at': collectedAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  /// Create PrintJobModel from PrintJobEntity
  factory PrintJobModel.fromEntity(PrintJobEntity entity) {
    return PrintJobModel(
      id: entity.id,
      userId: entity.userId,
      fileName: entity.fileName,
      fileUrl: entity.fileUrl,
      fileSizeBytes: entity.fileSizeBytes,
      mimeType: entity.mimeType,
      totalPages: entity.totalPages,
      bwPages: entity.bwPages,
      colorPages: entity.colorPages,
      colorMode: entity.colorMode,
      copies: entity.copies,
      totalAmount: entity.totalAmount,
      status: entity.status,
      pickupCode: entity.pickupCode,
      createdAt: entity.createdAt,
      paymentAt: entity.paymentAt,
      printingStartedAt: entity.printingStartedAt,
      readyAt: entity.readyAt,
      collectedAt: entity.collectedAt,
      expiredAt: entity.expiredAt,
      errorMessage: entity.errorMessage,
    );
  }

  /// Convert to PrintJobEntity
  PrintJobEntity toEntity() {
    return PrintJobEntity(
      id: id,
      userId: userId,
      fileName: fileName,
      fileUrl: fileUrl,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      totalPages: totalPages,
      bwPages: bwPages,
      colorPages: colorPages,
      colorMode: colorMode,
      copies: copies,
      totalAmount: totalAmount,
      status: status,
      pickupCode: pickupCode,
      createdAt: createdAt,
      paymentAt: paymentAt,
      printingStartedAt: printingStartedAt,
      readyAt: readyAt,
      collectedAt: collectedAt,
      expiredAt: expiredAt,
      errorMessage: errorMessage,
    );
  }
}
