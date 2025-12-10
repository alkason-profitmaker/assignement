import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import '../models/document.dart';

/// Service for document processing - PDF and image handling
class DocumentService {
  /// Pick a document from device
  Future<DocumentProcessingResult> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedFileTypes,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return DocumentProcessingResult.failure(
          DocumentProcessingError.unknown,
          'No file selected',
        );
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return DocumentProcessingResult.failure(
          DocumentProcessingError.readError,
          'Could not read file data',
        );
      }

      return await processDocument(
        name: file.name,
        path: file.path ?? '',
        bytes: file.bytes!,
      );
    } catch (e) {
      return DocumentProcessingResult.failure(
        DocumentProcessingError.unknown,
        e.toString(),
      );
    }
  }

  /// Pick multiple images for collage
  Future<List<CollagePhoto>?> pickImages({int maxImages = 20}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final photos = <CollagePhoto>[];
      for (final file in result.files.take(maxImages)) {
        if (file.bytes != null) {
          final image = img.decodeImage(file.bytes!);
          if (image != null) {
            photos.add(CollagePhoto(
              path: file.path ?? file.name,
              bytes: file.bytes!,
              widthPx: image.width,
              heightPx: image.height,
            ));
          }
        }
      }

      return photos.isEmpty ? null : photos;
    } catch (e) {
      return null;
    }
  }

  /// Process document and extract metadata
  Future<DocumentProcessingResult> processDocument({
    required String name,
    required String path,
    required Uint8List bytes,
  }) async {
    // Check file size
    final sizeMB = bytes.length / (1024 * 1024);
    if (sizeMB > AppConstants.maxFileSizeMB) {
      return DocumentProcessingResult.failure(
        DocumentProcessingError.fileTooLarge,
        'File size ${sizeMB.toStringAsFixed(1)} MB exceeds ${AppConstants.maxFileSizeMB} MB limit',
      );
    }

    // Determine document type
    final extension = name.split('.').last.toLowerCase();
    final docType = DocumentType.fromExtension(extension);

    if (docType == null) {
      return DocumentProcessingResult.failure(
        DocumentProcessingError.unsupportedFormat,
        'Unsupported file format: $extension',
      );
    }

    try {
      List<PageInfo> pages;
      if (docType == DocumentType.pdf) {
        pages = await _processPdf(bytes);
      } else {
        pages = await _processImage(bytes);
      }

      if (pages.length > AppConstants.maxPagesPerOrder) {
        return DocumentProcessingResult.failure(
          DocumentProcessingError.tooManyPages,
          'Document has ${pages.length} pages, maximum allowed is ${AppConstants.maxPagesPerOrder}',
        );
      }

      final document = PrintDocument(
        name: name,
        path: path,
        type: docType,
        bytes: bytes,
        totalPages: pages.length,
        pages: pages,
        fileSizeBytes: bytes.length,
        selectedAt: DateTime.now(),
      );

      return DocumentProcessingResult.success(document);
    } catch (e) {
      if (e.toString().contains('password')) {
        return DocumentProcessingResult.failure(
          DocumentProcessingError.passwordProtected,
        );
      }
      return DocumentProcessingResult.failure(
        DocumentProcessingError.corruptedFile,
        e.toString(),
      );
    }
  }

  /// Process PDF document
  Future<List<PageInfo>> _processPdf(Uint8List bytes) async {
    // Note: In a real implementation, use pdf package to parse PDF
    // This is a simplified version that estimates pages from file size
    // For production, integrate syncfusion_flutter_pdf or similar

    final pages = <PageInfo>[];

    // Simple heuristic: average PDF page is ~50KB
    // This is just for MVP - real implementation should parse PDF
    final estimatedPages = (bytes.length / 50000).ceil().clamp(1, 100);

    for (var i = 1; i <= estimatedPages; i++) {
      pages.add(PageInfo(
        pageNumber: i,
        isColor: false, // Default to B/W, real impl should detect
        widthPx: 595, // A4 @ 72dpi
        heightPx: 842,
      ));
    }

    return pages;
  }

  /// Process image file
  Future<List<PageInfo>> _processImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Could not decode image');
    }

    final isColor = _detectColor(image);

    return [
      PageInfo(
        pageNumber: 1,
        isColor: isColor,
        widthPx: image.width,
        heightPx: image.height,
        thumbnail: _generateThumbnail(image),
      ),
    ];
  }

  /// Detect if image has significant color
  bool _detectColor(img.Image image) {
    // Sample pixels to detect color
    const sampleSize = 100;
    final step = (image.width * image.height / sampleSize).ceil();

    var colorPixels = 0;
    for (var i = 0; i < image.width * image.height; i += step) {
      final x = i % image.width;
      final y = i ~/ image.width;
      final pixel = image.getPixel(x, y);

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Check if pixel has significant color (not grayscale)
      final maxDiff = [
        (r - g).abs(),
        (g - b).abs(),
        (r - b).abs(),
      ].reduce((a, b) => a > b ? a : b);

      if (maxDiff > 20) {
        colorPixels++;
      }
    }

    // If more than 10% of sampled pixels are colored, consider it a color document
    return colorPixels > sampleSize * 0.1;
  }

  /// Generate thumbnail for preview
  Uint8List? _generateThumbnail(img.Image image) {
    try {
      final thumbnail = img.copyResize(
        image,
        width: 200,
        height: (200 * image.height / image.width).round(),
      );
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));
    } catch (e) {
      return null;
    }
  }

  /// Generate photo collage as PDF bytes
  Future<Uint8List> generateCollage(PhotoCollage collage) async {
    // Note: Real implementation would use pdf package to generate PDF
    // This is a placeholder that returns the first image
    // For production, implement proper collage generation

    if (collage.photos.isEmpty) {
      throw Exception('No photos provided');
    }

    // Placeholder: return first photo
    // Real impl should arrange photos in collage layout
    return collage.photos.first.bytes;
  }

  /// Calculate file hash for deduplication
  String calculateFileHash(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
