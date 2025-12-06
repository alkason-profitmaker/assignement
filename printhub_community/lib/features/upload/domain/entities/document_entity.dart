import 'package:equatable/equatable.dart';

/// Document entity representing an uploaded document
class DocumentEntity extends Equatable {
  final String id;
  final String fileName;
  final String filePath;
  final String? fileUrl;
  final int fileSizeBytes;
  final String mimeType;
  final int totalPages;
  final int bwPages;
  final int colorPages;
  final bool hasColorPages;
  final DateTime createdAt;

  const DocumentEntity({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.fileUrl,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.totalPages,
    this.bwPages = 0,
    this.colorPages = 0,
    this.hasColorPages = false,
    required this.createdAt,
  });

  /// File extension
  String get extension => fileName.split('.').last.toLowerCase();

  /// Is PDF file
  bool get isPdf => extension == 'pdf' || mimeType == 'application/pdf';

  /// Is image file
  bool get isImage =>
      ['jpg', 'jpeg', 'png'].contains(extension) ||
      mimeType.startsWith('image/');

  /// Formatted file size
  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  DocumentEntity copyWith({
    String? id,
    String? fileName,
    String? filePath,
    String? fileUrl,
    int? fileSizeBytes,
    String? mimeType,
    int? totalPages,
    int? bwPages,
    int? colorPages,
    bool? hasColorPages,
    DateTime? createdAt,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      totalPages: totalPages ?? this.totalPages,
      bwPages: bwPages ?? this.bwPages,
      colorPages: colorPages ?? this.colorPages,
      hasColorPages: hasColorPages ?? this.hasColorPages,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        filePath,
        fileUrl,
        fileSizeBytes,
        mimeType,
        totalPages,
        bwPages,
        colorPages,
        hasColorPages,
        createdAt,
      ];
}
