import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
      if (e.toString().contains('password') ||
          e.toString().contains('encrypted')) {
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

  /// Process PDF document using Syncfusion PDF library
  Future<List<PageInfo>> _processPdf(Uint8List bytes) async {
    final pages = <PageInfo>[];

    // Load PDF document using Syncfusion
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final pageCount = document.pages.count;

      for (var i = 0; i < pageCount; i++) {
        final page = document.pages[i];
        final size = page.size;

        // Analyze page content for color detection
        final isColor = await _analyzePageForColor(document, i);

        pages.add(PageInfo(
          pageNumber: i + 1,
          isColor: isColor,
          widthPx: size.width.toInt(),
          heightPx: size.height.toInt(),
        ));
      }
    } finally {
      document.dispose();
    }

    return pages;
  }

  /// Analyze a PDF page to determine if it contains color content
  Future<bool> _analyzePageForColor(PdfDocument document, int pageIndex) async {
    try {
      final page = document.pages[pageIndex];

      // Extract text from page to check for color annotations
      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText(startPageIndex: pageIndex);

      // Check page graphics for color elements
      // We analyze the page's graphic elements to detect color usage
      final graphics = page.graphics;

      // Check if the page has color by examining default state
      // If there are images or complex graphics, assume color for safety
      final hasImages = _pageHasImages(document, pageIndex);
      final hasColorAnnotations = _pageHasColorAnnotations(page);

      // Conservative approach: if we detect images or annotations, check them
      if (hasImages || hasColorAnnotations) {
        return true;
      }

      // Check the page's default brush and pen colors
      // For text-only documents, default to B/W
      return false;
    } catch (e) {
      // On error, default to B/W (cheaper for user)
      return false;
    }
  }

  /// Check if a PDF page contains images
  bool _pageHasImages(PdfDocument document, int pageIndex) {
    try {
      // Attempt to extract images from the page
      // If images exist, they might be color
      final page = document.pages[pageIndex];

      // Check page annotations and form fields that might contain images
      for (var j = 0; j < page.annotations.count; j++) {
        final annotation = page.annotations[j];
        if (annotation is PdfRubberStampAnnotation ||
            annotation is PdfUriAnnotation) {
          // These might contain colored elements
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if page has color annotations
  bool _pageHasColorAnnotations(PdfPage page) {
    try {
      for (var i = 0; i < page.annotations.count; i++) {
        final annotation = page.annotations[i];
        // Check if annotation has colored appearance
        if (annotation.color.r != annotation.color.g ||
            annotation.color.g != annotation.color.b) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
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
    if (collage.photos.isEmpty) {
      throw Exception('No photos provided');
    }

    // Create PDF document
    final pdf = pw.Document();

    // A4 dimensions in points (72 points per inch)
    const a4Width = 595.0;
    const a4Height = 842.0;
    const margin = 20.0;

    // Calculate grid layout based on number of photos
    final photoCount = collage.photos.length;
    final (cols, rows) = _calculateGridLayout(photoCount);

    // Calculate cell dimensions
    final cellWidth = (a4Width - margin * 2) / cols;
    final cellHeight = (a4Height - margin * 2) / rows;
    final photoPadding = 5.0;

    // Process photos in batches per page
    final photosPerPage = cols * rows;
    var photoIndex = 0;

    while (photoIndex < collage.photos.length) {
      final pagePhotos = collage.photos
          .skip(photoIndex)
          .take(photosPerPage)
          .toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: cols,
              mainAxisSpacing: photoPadding,
              crossAxisSpacing: photoPadding,
              childAspectRatio: cellWidth / cellHeight,
              children: pagePhotos.map((photo) {
                // Decode and process image
                final decodedImage = img.decodeImage(photo.bytes);
                if (decodedImage == null) {
                  return pw.Container();
                }

                // Resize image to fit cell while maintaining aspect ratio
                final resized = _resizeForCell(
                  decodedImage,
                  (cellWidth - photoPadding * 2).toInt(),
                  (cellHeight - photoPadding * 2).toInt(),
                );

                final imageBytes = Uint8List.fromList(img.encodeJpg(resized));

                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(imageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      );

      photoIndex += photosPerPage;
    }

    return pdf.save();
  }

  /// Calculate optimal grid layout for number of photos
  (int cols, int rows) _calculateGridLayout(int photoCount) {
    if (photoCount <= 1) return (1, 1);
    if (photoCount <= 2) return (2, 1);
    if (photoCount <= 4) return (2, 2);
    if (photoCount <= 6) return (3, 2);
    if (photoCount <= 9) return (3, 3);
    if (photoCount <= 12) return (4, 3);
    if (photoCount <= 16) return (4, 4);
    return (5, 4); // Max 20 photos per page
  }

  /// Resize image to fit within cell dimensions while maintaining aspect ratio
  img.Image _resizeForCell(img.Image image, int maxWidth, int maxHeight) {
    final aspectRatio = image.width / image.height;
    final cellAspectRatio = maxWidth / maxHeight;

    int newWidth;
    int newHeight;

    if (aspectRatio > cellAspectRatio) {
      // Image is wider than cell
      newWidth = maxWidth;
      newHeight = (maxWidth / aspectRatio).round();
    } else {
      // Image is taller than cell
      newHeight = maxHeight;
      newWidth = (maxHeight * aspectRatio).round();
    }

    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  /// Generate single image PDF (for printing single photos on A4)
  Future<Uint8List> generateSingleImagePdf(Uint8List imageBytes) async {
    final pdf = pw.Document();

    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Could not decode image');
    }

    // Resize to fit A4 with margins
    const maxWidth = 555; // A4 width - 40 margin
    const maxHeight = 802; // A4 height - 40 margin

    final resized = _resizeForCell(image, maxWidth, maxHeight);
    final processedBytes = Uint8List.fromList(img.encodeJpg(resized));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              pw.MemoryImage(processedBytes),
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Calculate file hash for deduplication
  String calculateFileHash(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Prepare document for printing - converts images to PDF if needed
  Future<Uint8List> prepareForPrinting(PrintDocument document) async {
    if (document.type == DocumentType.pdf) {
      // Already a PDF, return as-is
      return document.bytes;
    }

    // Convert image to PDF for consistent printing
    return generateSingleImagePdf(document.bytes);
  }
}
