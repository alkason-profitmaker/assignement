import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

/// Print job entity representing a print job
class PrintJobEntity extends Equatable {
  final String id;
  final String userId;
  final String fileName;
  final String fileUrl;
  final int fileSizeBytes;
  final String mimeType;
  final int totalPages;
  final int bwPages;
  final int colorPages;
  final String colorMode;
  final int copies;
  final double totalAmount;
  final PrintJobStatus status;
  final String? pickupCode;
  final DateTime createdAt;
  final DateTime? paymentAt;
  final DateTime? printingStartedAt;
  final DateTime? readyAt;
  final DateTime? collectedAt;
  final DateTime? expiredAt;
  final String? errorMessage;

  const PrintJobEntity({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.totalPages,
    this.bwPages = 0,
    this.colorPages = 0,
    required this.colorMode,
    this.copies = 1,
    required this.totalAmount,
    required this.status,
    this.pickupCode,
    required this.createdAt,
    this.paymentAt,
    this.printingStartedAt,
    this.readyAt,
    this.collectedAt,
    this.expiredAt,
    this.errorMessage,
  });

  /// Is this job active (not yet collected/expired/failed)
  bool get isActive => [
        PrintJobStatus.pending,
        PrintJobStatus.processing,
        PrintJobStatus.printing,
        PrintJobStatus.ready,
      ].contains(status);

  /// Is this job ready for collection
  bool get isReady => status == PrintJobStatus.ready;

  /// Is this job completed (collected or expired)
  bool get isCompleted => [
        PrintJobStatus.collected,
        PrintJobStatus.expired,
        PrintJobStatus.failed,
        PrintJobStatus.refunded,
      ].contains(status);

  /// Time remaining for collection (if ready)
  Duration? get timeRemaining {
    if (status != PrintJobStatus.ready || readyAt == null) return null;
    final expiryTime = readyAt!.add(
      Duration(minutes: AppConstants.documentRetentionMinutes),
    );
    final remaining = expiryTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Status display text
  String get statusText => status.title;

  /// Status description
  String get statusDescription => status.description;

  PrintJobEntity copyWith({
    String? id,
    String? userId,
    String? fileName,
    String? fileUrl,
    int? fileSizeBytes,
    String? mimeType,
    int? totalPages,
    int? bwPages,
    int? colorPages,
    String? colorMode,
    int? copies,
    double? totalAmount,
    PrintJobStatus? status,
    String? pickupCode,
    DateTime? createdAt,
    DateTime? paymentAt,
    DateTime? printingStartedAt,
    DateTime? readyAt,
    DateTime? collectedAt,
    DateTime? expiredAt,
    String? errorMessage,
  }) {
    return PrintJobEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      totalPages: totalPages ?? this.totalPages,
      bwPages: bwPages ?? this.bwPages,
      colorPages: colorPages ?? this.colorPages,
      colorMode: colorMode ?? this.colorMode,
      copies: copies ?? this.copies,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      pickupCode: pickupCode ?? this.pickupCode,
      createdAt: createdAt ?? this.createdAt,
      paymentAt: paymentAt ?? this.paymentAt,
      printingStartedAt: printingStartedAt ?? this.printingStartedAt,
      readyAt: readyAt ?? this.readyAt,
      collectedAt: collectedAt ?? this.collectedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fileName,
        fileUrl,
        fileSizeBytes,
        mimeType,
        totalPages,
        bwPages,
        colorPages,
        colorMode,
        copies,
        totalAmount,
        status,
        pickupCode,
        createdAt,
        paymentAt,
        printingStartedAt,
        readyAt,
        collectedAt,
        expiredAt,
        errorMessage,
      ];
}
