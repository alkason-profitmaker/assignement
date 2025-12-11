import 'dart:typed_data';

/// Model representing a document being prepared for printing
class PrintDocument {
  final String name;
  final String path;
  final DocumentType type;
  final Uint8List bytes;
  final int totalPages;
  final List<PageInfo> pages;
  final int fileSizeBytes;
  final DateTime selectedAt;

  PrintDocument({
    required this.name,
    required this.path,
    required this.type,
    required this.bytes,
    required this.totalPages,
    required this.pages,
    required this.fileSizeBytes,
    required this.selectedAt,
  });

  /// Count of B/W pages
  int get bwPageCount => pages.where((p) => !p.isColor).length;

  /// Count of color pages
  int get colorPageCount => pages.where((p) => p.isColor).length;

  /// File size in MB
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  /// Check if file size is within limits
  bool get isValidSize => fileSizeMB <= 25; // 25 MB limit

  /// Check if page count is within limits
  bool get isValidPageCount => totalPages <= 50; // 50 pages limit

  /// Check if document is valid for printing
  bool get isValid => isValidSize && isValidPageCount;

  @override
  String toString() => 'PrintDocument(name: $name, pages: $totalPages, bw: $bwPageCount, color: $colorPageCount)';
}

/// Information about a single page in a document
class PageInfo {
  final int pageNumber;
  final bool isColor;
  final int widthPx;
  final int heightPx;
  final Uint8List? thumbnail;

  PageInfo({
    required this.pageNumber,
    required this.isColor,
    this.widthPx = 0,
    this.heightPx = 0,
    this.thumbnail,
  });

  /// Page orientation
  bool get isLandscape => widthPx > heightPx;

  @override
  String toString() => 'PageInfo(page: $pageNumber, isColor: $isColor)';
}

/// Supported document types
enum DocumentType {
  pdf('PDF', 'application/pdf', ['pdf']),
  image('Image', 'image/*', ['jpg', 'jpeg', 'png']);

  final String label;
  final String mimeType;
  final List<String> extensions;

  const DocumentType(this.label, this.mimeType, this.extensions);

  static DocumentType? fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    for (final type in DocumentType.values) {
      if (type.extensions.contains(ext)) {
        return type;
      }
    }
    return null;
  }

  static DocumentType? fromMimeType(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime == 'application/pdf') return DocumentType.pdf;
    if (mime.startsWith('image/')) return DocumentType.image;
    return null;
  }
}

/// Result of document processing
class DocumentProcessingResult {
  final bool success;
  final PrintDocument? document;
  final String? errorMessage;
  final DocumentProcessingError? error;

  DocumentProcessingResult.success(this.document)
      : success = true,
        errorMessage = null,
        error = null;

  DocumentProcessingResult.failure(this.error, [this.errorMessage])
      : success = false,
        document = null;
}

/// Possible document processing errors
enum DocumentProcessingError {
  unsupportedFormat('Unsupported file format'),
  fileTooLarge('File size exceeds 25 MB limit'),
  tooManyPages('Document exceeds 50 pages limit'),
  passwordProtected('Password protected documents not supported'),
  corruptedFile('File appears to be corrupted'),
  readError('Unable to read file'),
  unknown('An unknown error occurred');

  final String message;
  const DocumentProcessingError(this.message);
}

/// Photo collage configuration for printing multiple photos
class PhotoCollage {
  final List<CollagePhoto> photos;
  final CollageLayout layout;
  final PaperSize paperSize;

  PhotoCollage({
    required this.photos,
    required this.layout,
    this.paperSize = PaperSize.a4,
  });

  int get totalSheets => (photos.length / layout.photosPerPage).ceil();
}

/// Individual photo in a collage
class CollagePhoto {
  final String path;
  final Uint8List bytes;
  final int widthPx;
  final int heightPx;

  CollagePhoto({
    required this.path,
    required this.bytes,
    required this.widthPx,
    required this.heightPx,
  });
}

/// Collage layout options
enum CollageLayout {
  twoByOne(2, 1, '2×1 Large (2 per page)'),
  twoByTwo(2, 2, '2×2 Standard (4 per page)'),
  threeByTwo(3, 2, '3×2 Wallet (6 per page)'),
  fourByTwo(4, 2, '4×2 Passport (8 per page)');

  final int cols;
  final int rows;
  final String label;
  const CollageLayout(this.cols, this.rows, this.label);

  int get photosPerPage => cols * rows;
}

/// Paper sizes
enum PaperSize {
  a4('A4', 210, 297),
  letter('Letter', 216, 279),
  a5('A5', 148, 210);

  final String label;
  final int widthMm;
  final int heightMm;
  const PaperSize(this.label, this.widthMm, this.heightMm);
}
