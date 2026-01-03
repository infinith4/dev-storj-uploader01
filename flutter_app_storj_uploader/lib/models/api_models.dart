import 'dart:typed_data';

// API Response Models
class UploadResponse {
  final String message;
  final List<FileUploadResult> results;
  final int totalFiles;
  final int successfulUploads;
  final int failedUploads;
  final Map<String, dynamic> metadata;

  UploadResponse({
    required this.message,
    required this.results,
    required this.totalFiles,
    required this.successfulUploads,
    required this.failedUploads,
    required this.metadata,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      message: json['message'] ?? '',
      results: (json['results'] as List?)
          ?.map((item) => FileUploadResult.fromJson(item))
          .toList() ?? [],
      totalFiles: json['total_files'] ?? 0,
      successfulUploads: json['successful_uploads'] ?? 0,
      failedUploads: json['failed_uploads'] ?? 0,
      metadata: json['metadata'] ?? {},
    );
  }
}

class FileUploadResult {
  final String filename;
  final String status;
  final String? message;  // Error or success message from backend
  final String? savedAs;  // The filename saved on server
  final FileInfo? fileInfo;

  FileUploadResult({
    required this.filename,
    required this.status,
    this.message,
    this.savedAs,
    this.fileInfo,
  });

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  factory FileUploadResult.fromJson(Map<String, dynamic> json) {
    return FileUploadResult(
      filename: json['filename'] ?? '',
      status: json['status'] ?? '',
      message: json['message'],  // Backend sends error messages in 'message' field
      savedAs: json['saved_as'],
      fileInfo: json['file_info'] != null
          ? FileInfo.fromJson(json['file_info'])
          : null,
    );
  }
}

class FileInfo {
  final String originalName;
  final String savedName;
  final String contentType;
  final int size;
  final String uploadTime;
  final String? thumbnail;

  FileInfo({
    required this.originalName,
    required this.savedName,
    required this.contentType,
    required this.size,
    required this.uploadTime,
    this.thumbnail,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      originalName: json['original_name'] ?? '',
      savedName: json['saved_name'] ?? '',
      contentType: json['content_type'] ?? '',
      size: json['size'] ?? 0,
      uploadTime: json['upload_time'] ?? '',
      thumbnail: json['thumbnail'],
    );
  }
}

class HealthResponse {
  final String status;
  final String message;
  final String timestamp;
  final Map<String, dynamic> systemInfo;

  HealthResponse({
    required this.status,
    required this.message,
    required this.timestamp,
    required this.systemInfo,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
      systemInfo: json['system_info'] ?? {},
    );
  }
}

class StatusResponse {
  final int uploadQueueCount;
  final int totalUploaded;
  final String lastUploadTime;
  final bool storjServiceRunning;
  final Map<String, dynamic> statistics;

  // Additional fields from API response
  final ApiInfo? apiInfo;
  final StorjStatus? storjStatus;

  StatusResponse({
    required this.uploadQueueCount,
    required this.totalUploaded,
    required this.lastUploadTime,
    required this.storjServiceRunning,
    required this.statistics,
    this.apiInfo,
    this.storjStatus,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    bool _parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'y') {
          return true;
        }
        if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'n') {
          return false;
        }
      }
      if (value is num) return value != 0;
      return false;
    }

    // Parse nested storj_status object
    final storjStatusJson = json['storj_status'] as Map<String, dynamic>?;
    final apiInfoJson = json['api_info'] as Map<String, dynamic>?;

    // Debug output
    print('DEBUG StatusResponse.fromJson: storjStatusJson = $storjStatusJson');
    print('DEBUG StatusResponse.fromJson: storj_app_available = ${storjStatusJson?['storj_app_available']}');

    // Extract values from nested structure
    final filesInTarget = storjStatusJson?['files_in_target'] ?? apiInfoJson?['files_in_target'] ?? 0;
    final filesUploaded = storjStatusJson?['files_uploaded'] ?? 0;
    final storjAppMode = storjStatusJson?['storj_app_mode']?.toString() ?? 'unknown';
    final storjAppAvailable = _parseBool(storjStatusJson?['storj_app_available']);
    final storjRunning = storjAppAvailable || storjAppMode == 'remote';

    print('DEBUG StatusResponse.fromJson: storjAppAvailable = $storjAppAvailable (type: ${storjAppAvailable.runtimeType})');
    print('DEBUG StatusResponse.fromJson: storjAppMode = $storjAppMode');

    return StatusResponse(
      uploadQueueCount: filesInTarget is int ? filesInTarget : 0,
      totalUploaded: filesUploaded is int ? filesUploaded : 0,
      lastUploadTime: json['last_upload_time'] ?? '',
      storjServiceRunning: storjRunning,
      statistics: json['statistics'] ?? {},
      apiInfo: apiInfoJson != null ? ApiInfo.fromJson(apiInfoJson) : null,
      storjStatus: storjStatusJson != null ? StorjStatus.fromJson(storjStatusJson) : null,
    );
  }
}

class ApiInfo {
  final String uploadTargetDir;
  final String tempDir;
  final int filesInTarget;
  final int filesInTemp;
  final List<String> supportedImageFormats;
  final double maxFileSizeMb;

  ApiInfo({
    required this.uploadTargetDir,
    required this.tempDir,
    required this.filesInTarget,
    required this.filesInTemp,
    required this.supportedImageFormats,
    required this.maxFileSizeMb,
  });

  factory ApiInfo.fromJson(Map<String, dynamic> json) {
    return ApiInfo(
      uploadTargetDir: json['upload_target_dir'] ?? '',
      tempDir: json['temp_dir'] ?? '',
      filesInTarget: json['files_in_target'] ?? 0,
      filesInTemp: json['files_in_temp'] ?? 0,
      supportedImageFormats: (json['supported_image_formats'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      maxFileSizeMb: (json['max_file_size_mb'] ?? 0).toDouble(),
    );
  }
}

class StorjStatus {
  final bool storjAppAvailable;
  final String storjAppMode;
  final String storjAppPath;
  final String uploadTargetDir;
  final String uploadedDir;
  final int filesInTarget;
  final int filesUploaded;
  final bool targetDirExists;
  final bool uploadedDirExists;

  StorjStatus({
    required this.storjAppAvailable,
    required this.storjAppMode,
    required this.storjAppPath,
    required this.uploadTargetDir,
    required this.uploadedDir,
    required this.filesInTarget,
    required this.filesUploaded,
    required this.targetDirExists,
    required this.uploadedDirExists,
  });

  factory StorjStatus.fromJson(Map<String, dynamic> json) {
    return StorjStatus(
      storjAppAvailable: json['storj_app_available'] ?? false,
      storjAppMode: json['storj_app_mode']?.toString() ?? 'unknown',
      storjAppPath: json['storj_app_path'] ?? '',
      uploadTargetDir: json['upload_target_dir'] ?? '',
      uploadedDir: json['uploaded_dir'] ?? '',
      filesInTarget: json['files_in_target'] ?? 0,
      filesUploaded: json['files_uploaded'] ?? 0,
      targetDirExists: json['target_dir_exists'] ?? false,
      uploadedDirExists: json['uploaded_dir_exists'] ?? false,
    );
  }
}

class TriggerUploadResponse {
  final String message;
  final String status;
  final String? taskId;
  final Map<String, dynamic> details;

  TriggerUploadResponse({
    required this.message,
    required this.status,
    this.taskId,
    required this.details,
  });

  factory TriggerUploadResponse.fromJson(Map<String, dynamic> json) {
    return TriggerUploadResponse(
      message: json['message'] ?? '',
      status: json['status'] ?? '',
      taskId: json['task_id'],
      details: json['details'] ?? {},
    );
  }
}

class DeleteMediaFailure {
  final String path;
  final String message;

  DeleteMediaFailure({
    required this.path,
    required this.message,
  });

  factory DeleteMediaFailure.fromJson(Map<String, dynamic> json) {
    return DeleteMediaFailure(
      path: json['path'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class DeleteMediaResponse {
  final bool success;
  final List<String> deleted;
  final List<DeleteMediaFailure> failed;
  final String message;

  DeleteMediaResponse({
    required this.success,
    required this.deleted,
    required this.failed,
    required this.message,
  });

  factory DeleteMediaResponse.fromJson(Map<String, dynamic> json) {
    final deletedList = json['deleted'] is List
        ? List<String>.from(json['deleted'])
        : <String>[];
    final failedList = json['failed'] is List
        ? (json['failed'] as List)
            .whereType<Map<String, dynamic>>()
            .map(DeleteMediaFailure.fromJson)
            .toList()
        : <DeleteMediaFailure>[];

    return DeleteMediaResponse(
      success: json['success'] ?? false,
      deleted: deletedList,
      failed: failedList,
      message: json['message'] ?? '',
    );
  }
}

// Local File Model
class LocalFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String type;
  final DateTime dateAdded;
  final String? thumbnailPath;
  final FileUploadStatus uploadStatus;
  final String? errorMessage;
  final Uint8List? bytes; // For web platform - stores file data in memory
  final Object? webFile; // For web platform - stores a browser File reference

  LocalFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    required this.dateAdded,
    this.thumbnailPath,
    this.uploadStatus = FileUploadStatus.pending,
    this.errorMessage,
    this.bytes,
    this.webFile,
  });

  LocalFile copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    String? type,
    DateTime? dateAdded,
    String? thumbnailPath,
    FileUploadStatus? uploadStatus,
    String? errorMessage,
    Uint8List? bytes,
    Object? webFile,
  }) {
    return LocalFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      type: type ?? this.type,
      dateAdded: dateAdded ?? this.dateAdded,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      bytes: bytes ?? this.bytes,
      webFile: webFile ?? this.webFile,
    );
  }
}

enum FileUploadStatus {
  pending,
  uploading,
  uploaded,
  failed,
}

// Storj Image/Video Item Model
class StorjImageItem {
  final String filename;
  final String path;
  final int size;
  final String modifiedTime;
  final String thumbnailUrl;
  final String url;
  final bool isVideo;

  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.3gp',
    '.flv',
    '.wmv',
  };

  StorjImageItem({
    required this.filename,
    required this.path,
    required this.size,
    required this.modifiedTime,
    required this.thumbnailUrl,
    required this.url,
    required this.isVideo,
  });

  static bool _looksLikeVideoPath(String value) {
    if (value.isEmpty) return false;
    final normalized = value.toLowerCase();
    final pathOnly = normalized.split('?').first;
    final dotIndex = pathOnly.lastIndexOf('.');
    if (dotIndex < 0) return false;
    return _videoExtensions.contains(pathOnly.substring(dotIndex));
  }

  static bool _parseIsVideo(
    dynamic rawValue,
    String filename,
    String path,
    String url,
    String thumbnailUrl,
  ) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue != 0;
    if (rawValue is String) {
      final normalized = rawValue.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return _looksLikeVideoPath(filename) ||
        _looksLikeVideoPath(path) ||
        _looksLikeVideoPath(url) ||
        _looksLikeVideoPath(thumbnailUrl);
  }

  factory StorjImageItem.fromJson(Map<String, dynamic> json) {
    final filename = json['filename'] ?? '';
    final path = json['path'] ?? '';
    final thumbnailUrl = json['thumbnail_url'] ?? '';
    final url = json['url'] ?? '';
    return StorjImageItem(
      filename: filename,
      path: path,
      size: json['size'] ?? 0,
      modifiedTime: json['modified_time'] ?? '',
      thumbnailUrl: thumbnailUrl,
      url: url,
      isVideo: _parseIsVideo(
        json['is_video'],
        filename,
        path,
        url,
        thumbnailUrl,
      ),
    );
  }

  // Helper to get formatted size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Helper to get formatted date
  String get formattedDate {
    try {
      final date = DateTime.parse(modifiedTime);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return modifiedTime;
    }
  }
}

// Storj Image List Response
class StorjImageListResponse {
  final bool success;
  final String? message;
  final List<StorjImageItem> images;
  final int total;
  final int limit;
  final int offset;

  StorjImageListResponse({
    required this.success,
    this.message,
    required this.images,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory StorjImageListResponse.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?)
            ?.map((item) => StorjImageItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    final totalCount = json['total_count'] ?? json['total'] ?? 0;
    return StorjImageListResponse(
      success: json['success'] ?? true,
      message: json['message'],
      images: images,
      total: totalCount is int ? totalCount : 0,
      limit: json['limit'] ?? images.length,
      offset: json['offset'] ?? 0,
    );
  }
}

// Upload Progress Model
class UploadProgress {
  final String fileId;
  final String fileName;
  final double progress;
  final int bytesUploaded;
  final int totalBytes;
  final FileUploadStatus status;
  final String? errorMessage;

  UploadProgress({
    required this.fileId,
    required this.fileName,
    required this.progress,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.status,
    this.errorMessage,
  });

  UploadProgress copyWith({
    String? fileId,
    String? fileName,
    double? progress,
    int? bytesUploaded,
    int? totalBytes,
    FileUploadStatus? status,
    String? errorMessage,
  }) {
    return UploadProgress(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
