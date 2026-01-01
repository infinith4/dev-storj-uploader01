import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/api_models.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void initialize({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? ApiConstants.defaultBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Request/Response interceptors for logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🚀 Request: ${options.method} ${options.path}');
        print('📤 Data: ${options.data}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ Response: ${response.statusCode}');
        print('📥 Data: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('❌ Error: ${error.message}');
        print('📥 Response: ${error.response?.data}');
        handler.next(error);
      },
    ));
  }

  // Health Check
  Future<HealthResponse> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return HealthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // System Status
  Future<StatusResponse> getStatus() async {
    try {
      final response = await _dio.get('/status');
      return StatusResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload Images (Multiple)
  Future<UploadResponse> uploadImages(
    List<File> files, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData();

      for (final file in files) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        ));
      }

      final response = await _dio.post(
        '/upload',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload Single Image
  Future<UploadResponse> uploadSingleImage(
    File file, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/upload/single',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload Files (Multiple - Any file type)
  Future<UploadResponse> uploadFiles(
    List<File> files, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData();

      for (final file in files) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        ));
      }

      final response = await _dio.post(
        '/upload/files',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload Single File (Any file type)
  Future<UploadResponse> uploadSingleFile(
    File file, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/upload/files/single',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload from Bytes (for web or memory-based uploads)
  Future<UploadResponse> uploadFromBytes(
    Uint8List bytes,
    String filename, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final response = await _dio.post(
        '/upload/files/single',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Trigger Manual Storj Upload
  Future<TriggerUploadResponse> triggerUpload() async {
    try {
      final response = await _dio.post('/trigger-upload');
      return TriggerUploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Trigger Async Storj Upload
  Future<TriggerUploadResponse> triggerUploadAsync() async {
    try {
      final response = await _dio.post('/trigger-upload-async');
      return TriggerUploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Test Connection
  Future<bool> testConnection() async {
    try {
      await healthCheck();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get Storj Images List
  Future<StorjImageListResponse> getStorjImages({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/storj/images',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      if (response.data is! Map<String, dynamic>) {
        throw ApiException(message: 'Invalid gallery response');
      }
      final parsed = StorjImageListResponse.fromJson(response.data);
      if (!parsed.success) {
        throw ApiException(
          message: parsed.message ?? 'Failed to load gallery',
        );
      }
      return parsed;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Get Storj Image/Video URL
  String getStorjMediaUrl(String path, {bool thumbnail = false}) {
    final baseUrl = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$baseUrl/storj/images/$path?thumbnail=$thumbnail';
  }

  // Get current base URL
  String get baseUrl => _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
}

// Custom Exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  factory ApiException.fromDioError(DioException error) {
    String message = 'Unknown error occurred';
    int? statusCode;
    Map<String, dynamic>? details;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Send timeout. Please try again.';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timeout. Server took too long to respond.';
        break;
      case DioExceptionType.badResponse:
        statusCode = error.response?.statusCode;
        if (error.response?.data is Map<String, dynamic>) {
          details = error.response?.data;
          message = details?['message'] ??
                   details?['detail'] ??
                   'Server error (${statusCode})';
        } else {
          message = 'Server error (${statusCode})';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        break;
      case DioExceptionType.connectionError:
        message = 'Connection error. Please check your internet connection.';
        break;
      case DioExceptionType.badCertificate:
        message = 'Bad certificate. Please check server configuration.';
        break;
      case DioExceptionType.unknown:
        message = error.message ?? 'Unknown error occurred';
        break;
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  @override
  String toString() {
    return 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}
