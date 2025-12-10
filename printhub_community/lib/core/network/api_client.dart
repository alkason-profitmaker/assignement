import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../logging/app_logger.dart';
import 'api_exception.dart';

/// Enterprise-grade HTTP client with interceptors
///
/// Features:
/// - Automatic retry with exponential backoff
/// - Request/Response logging
/// - Timeout handling
/// - Error standardization
/// - Certificate pinning ready
class ApiClient {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;
  final Map<String, String> defaultHeaders;

  ApiClient({
    http.Client? client,
    required this.baseUrl,
    Duration? timeout,
    int? maxRetries,
    Map<String, String>? defaultHeaders,
  })  : _client = client ?? http.Client(),
        timeout = timeout ?? AppConfig.apiTimeout,
        maxRetries = maxRetries ?? AppConfig.maxRetries,
        defaultHeaders = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Version': '1.0.0',
          'X-Platform': Platform.operatingSystem,
          ...?defaultHeaders,
        };

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
  }) async {
    return _executeWithRetry(
      () => _makeRequest(
        method: 'GET',
        path: path,
        queryParams: queryParams,
        headers: headers,
      ),
      parser: parser,
    );
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
  }) async {
    return _executeWithRetry(
      () => _makeRequest(
        method: 'POST',
        path: path,
        body: body,
        queryParams: queryParams,
        headers: headers,
      ),
      parser: parser,
    );
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
  }) async {
    return _executeWithRetry(
      () => _makeRequest(
        method: 'PUT',
        path: path,
        body: body,
        queryParams: queryParams,
        headers: headers,
      ),
      parser: parser,
    );
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
  }) async {
    return _executeWithRetry(
      () => _makeRequest(
        method: 'DELETE',
        path: path,
        queryParams: queryParams,
        headers: headers,
      ),
      parser: parser,
    );
  }

  Future<http.Response> _makeRequest({
    required String method,
    required String path,
    dynamic body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParams);
    final mergedHeaders = {...defaultHeaders, ...?headers};
    final stopwatch = Stopwatch()..start();

    AppLogger.network(method, uri.toString());

    try {
      http.Response response;

      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: mergedHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: mergedHeaders, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: mergedHeaders, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: mergedHeaders).timeout(timeout);
          break;
        default:
          throw ApiException.unknown('Unsupported HTTP method: $method');
      }

      stopwatch.stop();
      AppLogger.network(
        method,
        uri.toString(),
        statusCode: response.statusCode,
        duration: stopwatch.elapsed,
      );

      return response;
    } on SocketException catch (e) {
      throw ApiException.network('No internet connection', originalError: e);
    } on TimeoutException catch (e) {
      throw ApiException.timeout('Request timed out', originalError: e);
    } on http.ClientException catch (e) {
      throw ApiException.network('Network error: ${e.message}', originalError: e);
    }
  }

  Future<ApiResponse<T>> _executeWithRetry<T>(
    Future<http.Response> Function() request, {
    T Function(dynamic)? parser,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        final response = await request();
        return _handleResponse(response, parser);
      } on ApiException catch (e) {
        lastException = e;

        // Don't retry on client errors (4xx)
        if (!e.shouldRetry) rethrow;

        attempts++;
        if (attempts < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s, 8s...
          final delay = Duration(seconds: 1 << (attempts - 1));
          AppLogger.warning('Retry attempt $attempts after ${delay.inSeconds}s');
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ?? ApiException.unknown('Max retries exceeded');
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? parser,
  ) {
    final statusCode = response.statusCode;
    dynamic data;

    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
      }
    } catch (e) {
      data = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return ApiResponse.success(
        statusCode: statusCode,
        data: parser != null ? parser(data) : data as T?,
        rawData: data,
      );
    }

    // Handle error responses
    final message = _extractErrorMessage(data) ?? 'Request failed';

    switch (statusCode) {
      case 400:
        throw ApiException.badRequest(message, data: data);
      case 401:
        throw ApiException.unauthorized(message, data: data);
      case 403:
        throw ApiException.forbidden(message, data: data);
      case 404:
        throw ApiException.notFound(message, data: data);
      case 422:
        throw ApiException.validation(message, data: data);
      case 429:
        throw ApiException.rateLimited(message, data: data);
      case 500:
      case 502:
      case 503:
        throw ApiException.server(message, statusCode: statusCode, data: data);
      default:
        throw ApiException.unknown(message, statusCode: statusCode, data: data);
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          data['error'] as String? ??
          data['error_description'] as String?;
    }
    return null;
  }

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final fullPath = path.startsWith('http') ? path : '$baseUrl$path';
    final uri = Uri.parse(fullPath);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
    }

    return uri;
  }

  void dispose() {
    _client.close();
  }
}

/// API Response wrapper
class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final dynamic rawData;
  final bool success;

  ApiResponse.success({
    required this.statusCode,
    this.data,
    this.rawData,
  }) : success = true;

  ApiResponse.failure({
    required this.statusCode,
    this.data,
    this.rawData,
  }) : success = false;
}
