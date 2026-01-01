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
  final String? error;
  final FileInfo? fileInfo;

  FileUploadResult({
    required this.filename,
    required this.status,
    this.error,
    this.fileInfo,
  });

  factory FileUploadResult.fromJson(Map<String, dynamic> json) {
    return FileUploadResult(
      filename: json['filename'] ?? '',
      status: json['status'] ?? '',
      error: json['error'],
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

  StatusResponse({
    required this.uploadQueueCount,
    required this.totalUploaded,
    required this.lastUploadTime,
    required this.storjServiceRunning,
    required this.statistics,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      uploadQueueCount: json['upload_queue_count'] ?? 0,
      totalUploaded: json['total_uploaded'] ?? 0,
      lastUploadTime: json['last_upload_time'] ?? '',
      storjServiceRunning: json['storj_service_running'] ?? false,
      statistics: json['statistics'] ?? {},
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
    );
  }
}

enum FileUploadStatus {
  pending,
  uploading,
  uploaded,
  failed,
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