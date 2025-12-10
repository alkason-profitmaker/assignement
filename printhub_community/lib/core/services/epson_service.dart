import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/supabase_constants.dart';
import '../models/station.dart';

/// Service for Epson Connect cloud printing operations
class EpsonService {
  final String clientId;
  final String clientSecret;
  String? _accessToken;
  DateTime? _tokenExpiry;

  EpsonService({
    required this.clientId,
    required this.clientSecret,
  });

  static const String _baseUrl = ApiEndpoints.epsonBaseUrl;

  // ============================================
  // Authentication
  // ============================================

  /// Get or refresh access token
  Future<String> _getAccessToken() async {
    // Return cached token if still valid
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl${ApiEndpoints.epsonAuthEndpoint}'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'password',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    if (response.statusCode != 200) {
      throw EpsonException(
        'Authentication failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    _accessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    return _accessToken!;
  }

  // ============================================
  // Printer Status
  // ============================================

  /// Get printer status
  Future<StationStatus> getPrinterStatus(String printerEmail) async {
    try {
      final token = await _getAccessToken();
      final deviceId = _extractDeviceId(printerEmail);

      final response = await http.get(
        Uri.parse('$_baseUrl${ApiEndpoints.epsonPrintEndpoint}/$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return StationStatus.offline();
      }

      final data = jsonDecode(response.body);
      return StationStatus.fromEpsonResponse(data);
    } catch (e) {
      return StationStatus.offline();
    }
  }

  /// Check if printer is ready for printing
  Future<PrinterReadyResult> checkPrinterReady(String printerEmail) async {
    final status = await getPrinterStatus(printerEmail);

    if (!status.isOnline) {
      return PrinterReadyResult.notReady('Printer is offline');
    }

    if (status.hasPaperJam) {
      return PrinterReadyResult.notReady('Paper jam detected');
    }

    if (status.hasLowInk) {
      return PrinterReadyResult.notReady('Low ink level');
    }

    if (status.hasLowPaper) {
      return PrinterReadyResult.notReady('Low paper');
    }

    return PrinterReadyResult.ready(status);
  }

  // ============================================
  // Print Job Operations
  // ============================================

  /// Submit print job
  Future<EpsonPrintJob> submitPrintJob({
    required String printerEmail,
    required Uint8List documentBytes,
    required String fileName,
    required PrintSettings settings,
  }) async {
    final token = await _getAccessToken();
    final deviceId = _extractDeviceId(printerEmail);

    // Step 1: Create print job
    final createResponse = await http.post(
      Uri.parse('$_baseUrl${ApiEndpoints.epsonPrintEndpoint}/$deviceId/jobs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'job_name': fileName,
        'print_mode': settings.colorMode,
        'print_setting': {
          'media_size': settings.paperSize,
          'media_type': 'plain',
          'borderless': false,
          'print_quality': settings.quality,
          'source': 'auto',
          'color_mode': settings.colorMode,
          'two_sided': settings.duplex ? 'long' : 'none',
          'copies': settings.copies,
        },
      }),
    );

    if (createResponse.statusCode != 201) {
      throw EpsonException(
        'Failed to create print job',
        statusCode: createResponse.statusCode,
        body: createResponse.body,
      );
    }

    final jobData = jsonDecode(createResponse.body);
    final jobId = jobData['id'] as String;
    final uploadUri = jobData['upload_uri'] as String;

    // Step 2: Upload document
    final uploadResponse = await http.post(
      Uri.parse(uploadUri),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': _getMimeType(fileName),
        'Content-Length': documentBytes.length.toString(),
      },
      body: documentBytes,
    );

    if (uploadResponse.statusCode != 200) {
      throw EpsonException(
        'Failed to upload document',
        statusCode: uploadResponse.statusCode,
        body: uploadResponse.body,
      );
    }

    // Step 3: Execute print
    final executeResponse = await http.post(
      Uri.parse('$_baseUrl${ApiEndpoints.epsonPrintEndpoint}/$deviceId/jobs/$jobId/print'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (executeResponse.statusCode != 200) {
      throw EpsonException(
        'Failed to execute print job',
        statusCode: executeResponse.statusCode,
        body: executeResponse.body,
      );
    }

    return EpsonPrintJob(
      jobId: jobId,
      printerEmail: printerEmail,
      status: PrintJobStatus.queued,
      submittedAt: DateTime.now(),
    );
  }

  /// Get print job status
  Future<EpsonPrintJob> getJobStatus(String printerEmail, String jobId) async {
    final token = await _getAccessToken();
    final deviceId = _extractDeviceId(printerEmail);

    final response = await http.get(
      Uri.parse('$_baseUrl${ApiEndpoints.epsonJobStatusEndpoint}/$deviceId/jobs/$jobId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw EpsonException(
        'Failed to get job status',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    return EpsonPrintJob.fromJson(data, printerEmail);
  }

  /// Cancel print job
  Future<void> cancelJob(String printerEmail, String jobId) async {
    final token = await _getAccessToken();
    final deviceId = _extractDeviceId(printerEmail);

    final response = await http.delete(
      Uri.parse('$_baseUrl${ApiEndpoints.epsonPrintEndpoint}/$deviceId/jobs/$jobId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw EpsonException(
        'Failed to cancel job',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  // ============================================
  // Helper Methods
  // ============================================

  String _extractDeviceId(String printerEmail) {
    // Extract device ID from printer email
    // Format: device_id@print.epsonconnect.com
    return printerEmail.split('@').first;
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}

// ============================================
// Models
// ============================================

class PrintSettings {
  final String paperSize;
  final String colorMode;
  final String quality;
  final bool duplex;
  final int copies;

  PrintSettings({
    this.paperSize = 'ms_a4',
    this.colorMode = 'mono',
    this.quality = 'normal',
    this.duplex = false,
    this.copies = 1,
  });

  factory PrintSettings.forOrder({
    required bool hasColor,
    required int copies,
  }) {
    return PrintSettings(
      colorMode: hasColor ? 'color' : 'mono',
      copies: copies,
    );
  }
}

class EpsonPrintJob {
  final String jobId;
  final String printerEmail;
  final PrintJobStatus status;
  final String? errorCode;
  final String? errorMessage;
  final DateTime submittedAt;
  final DateTime? completedAt;

  EpsonPrintJob({
    required this.jobId,
    required this.printerEmail,
    required this.status,
    this.errorCode,
    this.errorMessage,
    required this.submittedAt,
    this.completedAt,
  });

  bool get isComplete => status == PrintJobStatus.completed;
  bool get isFailed => status == PrintJobStatus.failed;
  bool get isPending =>
      status == PrintJobStatus.queued || status == PrintJobStatus.printing;

  factory EpsonPrintJob.fromJson(Map<String, dynamic> json, String printerEmail) {
    final statusStr = json['status'] as String? ?? 'unknown';
    final status = PrintJobStatus.fromString(statusStr);

    return EpsonPrintJob(
      jobId: json['id'] as String,
      printerEmail: printerEmail,
      status: status,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      submittedAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

enum PrintJobStatus {
  queued('queued'),
  printing('printing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  unknown('unknown');

  final String value;
  const PrintJobStatus(this.value);

  static PrintJobStatus fromString(String value) {
    return PrintJobStatus.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => PrintJobStatus.unknown,
    );
  }
}

class PrinterReadyResult {
  final bool isReady;
  final String? errorMessage;
  final StationStatus? status;

  PrinterReadyResult._({
    required this.isReady,
    this.errorMessage,
    this.status,
  });

  factory PrinterReadyResult.ready(StationStatus status) {
    return PrinterReadyResult._(isReady: true, status: status);
  }

  factory PrinterReadyResult.notReady(String reason) {
    return PrinterReadyResult._(isReady: false, errorMessage: reason);
  }
}

// ============================================
// Exception
// ============================================

class EpsonException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  EpsonException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'EpsonException: $message (status: $statusCode)';
}
