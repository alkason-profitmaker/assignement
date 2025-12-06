import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/document_entity.dart';

// ============ EVENTS ============

abstract class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

class PickDocumentEvent extends UploadEvent {}

class AnalyzeDocumentEvent extends UploadEvent {
  final String filePath;
  final String fileName;
  final int fileSize;
  final Uint8List? fileBytes;

  const AnalyzeDocumentEvent({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.fileBytes,
  });

  @override
  List<Object?> get props => [filePath, fileName, fileSize];
}

class UploadDocumentEvent extends UploadEvent {
  final DocumentEntity document;

  const UploadDocumentEvent(this.document);

  @override
  List<Object?> get props => [document];
}

class CreatePrintJobEvent extends UploadEvent {
  final DocumentEntity document;
  final int copies;

  const CreatePrintJobEvent({
    required this.document,
    this.copies = 1,
  });

  @override
  List<Object?> get props => [document, copies];
}

class ResetUploadEvent extends UploadEvent {}

// ============ STATES ============

abstract class UploadState extends Equatable {
  const UploadState();

  @override
  List<Object?> get props => [];
}

class UploadInitial extends UploadState {}

class UploadLoading extends UploadState {
  final String message;
  final double? progress;

  const UploadLoading({
    this.message = 'Loading...',
    this.progress,
  });

  @override
  List<Object?> get props => [message, progress];
}

class DocumentPicked extends UploadState {
  final String filePath;
  final String fileName;
  final int fileSize;
  final Uint8List? fileBytes;

  const DocumentPicked({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.fileBytes,
  });

  @override
  List<Object?> get props => [filePath, fileName, fileSize];
}

class DocumentAnalyzed extends UploadState {
  final DocumentEntity document;

  const DocumentAnalyzed(this.document);

  @override
  List<Object?> get props => [document];
}

class DocumentUploaded extends UploadState {
  final DocumentEntity document;
  final String fileUrl;

  const DocumentUploaded({
    required this.document,
    required this.fileUrl,
  });

  @override
  List<Object?> get props => [document, fileUrl];
}

class PrintJobCreated extends UploadState {
  final String printJobId;
  final DocumentEntity document;
  final double totalAmount;
  final String pickupCode;

  const PrintJobCreated({
    required this.printJobId,
    required this.document,
    required this.totalAmount,
    required this.pickupCode,
  });

  @override
  List<Object?> get props => [printJobId, document, totalAmount, pickupCode];
}

class UploadError extends UploadState {
  final String message;

  const UploadError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============ BLOC ============

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final SupabaseClient supabase;
  final _uuid = const Uuid();

  UploadBloc({required this.supabase}) : super(UploadInitial()) {
    on<PickDocumentEvent>(_onPickDocument);
    on<AnalyzeDocumentEvent>(_onAnalyzeDocument);
    on<UploadDocumentEvent>(_onUploadDocument);
    on<CreatePrintJobEvent>(_onCreatePrintJob);
    on<ResetUploadEvent>(_onReset);
  }

  Future<void> _onPickDocument(
    PickDocumentEvent event,
    Emitter<UploadState> emit,
  ) async {
    try {
      emit(const UploadLoading(message: 'Opening file picker...'));

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedFileTypes,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        emit(UploadInitial());
        return;
      }

      final file = result.files.first;

      // Validate file size
      if (file.size > AppConstants.maxFileSizeBytes) {
        emit(UploadError(
          'File too large. Maximum size is ${AppConstants.maxFileSizeMb} MB.',
        ));
        return;
      }

      // Validate file type
      final extension = file.extension?.toLowerCase() ?? '';
      if (!AppConstants.allowedFileTypes.contains(extension)) {
        emit(const UploadError(
          'Invalid file type. Please upload PDF or image files only.',
        ));
        return;
      }

      emit(DocumentPicked(
        filePath: file.path ?? '',
        fileName: file.name,
        fileSize: file.size,
        fileBytes: file.bytes,
      ));

      // Auto-trigger analysis
      add(AnalyzeDocumentEvent(
        filePath: file.path ?? '',
        fileName: file.name,
        fileSize: file.size,
        fileBytes: file.bytes,
      ));
    } catch (e) {
      emit(UploadError('Failed to pick file: ${e.toString()}'));
    }
  }

  Future<void> _onAnalyzeDocument(
    AnalyzeDocumentEvent event,
    Emitter<UploadState> emit,
  ) async {
    try {
      emit(const UploadLoading(message: 'Analyzing document...'));

      final extension = event.fileName.split('.').last.toLowerCase();
      int totalPages = 1;
      int colorPages = 0;
      int bwPages = 1;
      bool hasColor = false;

      // Determine MIME type
      String mimeType;
      switch (extension) {
        case 'pdf':
          mimeType = 'application/pdf';
          // For PDF, we need to analyze page count
          // In production, use pdf_render or similar library
          totalPages = await _analyzePdfPages(event.filePath, event.fileBytes);
          bwPages = totalPages;
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          hasColor = await _analyzeImageColor(event.filePath, event.fileBytes);
          colorPages = hasColor ? 1 : 0;
          bwPages = hasColor ? 0 : 1;
          break;
        case 'png':
          mimeType = 'image/png';
          hasColor = await _analyzeImageColor(event.filePath, event.fileBytes);
          colorPages = hasColor ? 1 : 0;
          bwPages = hasColor ? 0 : 1;
          break;
        default:
          mimeType = 'application/octet-stream';
      }

      // Check page limit
      if (totalPages > AppConstants.maxPagesPerJob) {
        emit(UploadError(
          'Document has too many pages. Maximum ${AppConstants.maxPagesPerJob} pages allowed.',
        ));
        return;
      }

      final document = DocumentEntity(
        id: _uuid.v4(),
        fileName: event.fileName,
        filePath: event.filePath,
        fileSizeBytes: event.fileSize,
        mimeType: mimeType,
        totalPages: totalPages,
        bwPages: bwPages,
        colorPages: colorPages,
        hasColorPages: hasColor,
        createdAt: DateTime.now(),
      );

      emit(DocumentAnalyzed(document));
    } catch (e) {
      emit(UploadError('Failed to analyze document: ${e.toString()}'));
    }
  }

  Future<int> _analyzePdfPages(String filePath, Uint8List? fileBytes) async {
    try {
      // Simple PDF page count estimation
      // In production, use pdf_render or pdfium for accurate count
      if (fileBytes != null) {
        final content = String.fromCharCodes(fileBytes);
        final pageMatches = RegExp(r'/Type\s*/Page[^s]').allMatches(content);
        return pageMatches.length > 0 ? pageMatches.length : 1;
      }

      if (filePath.isNotEmpty) {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final content = String.fromCharCodes(bytes.take(50000).toList());
        final pageMatches = RegExp(r'/Type\s*/Page[^s]').allMatches(content);
        return pageMatches.length > 0 ? pageMatches.length : 1;
      }

      return 1;
    } catch (e) {
      return 1;
    }
  }

  Future<bool> _analyzeImageColor(String filePath, Uint8List? fileBytes) async {
    try {
      Uint8List bytes;

      if (fileBytes != null) {
        bytes = fileBytes;
      } else if (filePath.isNotEmpty) {
        bytes = await File(filePath).readAsBytes();
      } else {
        return false;
      }

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) return false;

      // Sample pixels to detect color
      int colorPixels = 0;
      const sampleSize = 100;
      final stepX = image.width ~/ 10;
      final stepY = image.height ~/ 10;

      for (int y = 0; y < image.height && colorPixels < sampleSize; y += stepY) {
        for (int x = 0; x < image.width && colorPixels < sampleSize; x += stepX) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Check if pixel is colorful (not grayscale)
          if ((r - g).abs() > 20 || (g - b).abs() > 20 || (r - b).abs() > 20) {
            colorPixels++;
          }
        }
      }

      // If more than 10% of sampled pixels are colorful, consider it a color image
      return colorPixels > (sampleSize * 0.1);
    } catch (e) {
      return false;
    }
  }

  Future<void> _onUploadDocument(
    UploadDocumentEvent event,
    Emitter<UploadState> emit,
  ) async {
    try {
      emit(const UploadLoading(message: 'Uploading document...'));

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        emit(const UploadError('Please login to upload documents'));
        return;
      }

      final storagePath =
          'uploads/$userId/${event.document.id}_${event.document.fileName}';

      Uint8List fileBytes;
      if (event.document.filePath.isNotEmpty) {
        fileBytes = await File(event.document.filePath).readAsBytes();
      } else {
        emit(const UploadError('File not found'));
        return;
      }

      // Upload to Supabase Storage
      final response = await supabase.storage.from('documents').uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: event.document.mimeType,
              upsert: true,
            ),
          );

      // Get public URL
      final fileUrl =
          supabase.storage.from('documents').getPublicUrl(storagePath);

      final uploadedDocument = event.document.copyWith(fileUrl: fileUrl);

      emit(DocumentUploaded(
        document: uploadedDocument,
        fileUrl: fileUrl,
      ));
    } catch (e) {
      emit(UploadError('Upload failed: ${e.toString()}'));
    }
  }

  Future<void> _onCreatePrintJob(
    CreatePrintJobEvent event,
    Emitter<UploadState> emit,
  ) async {
    try {
      emit(const UploadLoading(message: 'Creating print job...'));

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        emit(const UploadError('Please login to create print job'));
        return;
      }

      // First upload the document if not already uploaded
      String fileUrl = event.document.fileUrl ?? '';

      if (fileUrl.isEmpty) {
        final storagePath =
            'uploads/$userId/${event.document.id}_${event.document.fileName}';

        Uint8List fileBytes;
        if (event.document.filePath.isNotEmpty) {
          fileBytes = await File(event.document.filePath).readAsBytes();
        } else {
          emit(const UploadError('File not found'));
          return;
        }

        await supabase.storage.from('documents').uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: event.document.mimeType,
                upsert: true,
              ),
            );

        fileUrl = supabase.storage.from('documents').getPublicUrl(storagePath);
      }

      // Calculate total amount
      final bwAmount =
          event.document.bwPages * AppConstants.pricePerBwPage * event.copies;
      final colorAmount = event.document.colorPages *
          AppConstants.pricePerColorPage *
          event.copies;
      final totalAmount = bwAmount + colorAmount;

      // Determine color mode
      String colorMode;
      if (event.document.colorPages > 0 && event.document.bwPages > 0) {
        colorMode = 'mixed';
      } else if (event.document.colorPages > 0) {
        colorMode = 'color';
      } else {
        colorMode = 'bw';
      }

      // Create print job in database
      final printJobData = {
        'user_id': userId,
        'society_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', // Pilot society
        'file_name': event.document.fileName,
        'file_url': fileUrl,
        'file_size_bytes': event.document.fileSizeBytes,
        'mime_type': event.document.mimeType,
        'total_pages': event.document.totalPages,
        'bw_pages': event.document.bwPages,
        'color_pages': event.document.colorPages,
        'color_mode': colorMode,
        'copies': event.copies,
        'total_amount': totalAmount,
        'status': 'pending',
      };

      final response = await supabase
          .from('print_jobs')
          .insert(printJobData)
          .select()
          .single();

      emit(PrintJobCreated(
        printJobId: response['id'],
        document: event.document.copyWith(fileUrl: fileUrl),
        totalAmount: totalAmount,
        pickupCode: response['pickup_code'],
      ));
    } catch (e) {
      emit(UploadError('Failed to create print job: ${e.toString()}'));
    }
  }

  void _onReset(
    ResetUploadEvent event,
    Emitter<UploadState> emit,
  ) {
    emit(UploadInitial());
  }
}
