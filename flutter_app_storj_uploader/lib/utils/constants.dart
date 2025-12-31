import 'package:flutter_dotenv/flutter_dotenv.dart';

// API Constants
class ApiConstants {
  // Get API base URL from environment variables with fallback
  static String get defaultBaseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    // Fallback to localhost for development
    return 'http://localhost:8010';
  }

  // Endpoints
  static const String healthEndpoint = '/health';
  static const String statusEndpoint = '/status';
  static const String uploadImagesEndpoint = '/upload';
  static const String uploadSingleImageEndpoint = '/upload/single';
  static const String uploadFilesEndpoint = '/upload/files';
  static const String uploadSingleFileEndpoint = '/upload/files/single';
  static const String triggerUploadEndpoint = '/trigger-upload';
  static const String triggerUploadAsyncEndpoint = '/trigger-upload-async';
}

// App Constants
class AppConstants {
  static const String appName = 'Storj Uploader';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Flutter app for uploading files to Storj storage';

  // File size limits (in bytes)
  static const int maxFileSize = 500 * 1024 * 1024; // 500MB
  static const int maxImageSize = 50 * 1024 * 1024; // 50MB

  // Supported file types
  static const List<String> supportedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'
  ];

  static const List<String> supportedVideoTypes = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp'
  ];

  static const List<String> supportedDocumentTypes = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'
  ];

  // Upload settings
  static const int maxConcurrentUploads = 3;
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

// UI Constants
class UIConstants {
  // Colors
  static const int primaryColorValue = 0xFF2196F3;
  static const int accentColorValue = 0xFF03DAC6;
  static const int errorColorValue = 0xFFF44336;
  static const int warningColorValue = 0xFFFF9800;
  static const int successColorValue = 0xFF4CAF50;

  // Spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Border radius
  static const double defaultBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  // Icon sizes
  static const double smallIconSize = 16.0;
  static const double defaultIconSize = 24.0;
  static const double largeIconSize = 32.0;

  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
}

// Storage Keys for SharedPreferences
class StorageKeys {
  static const String apiBaseUrl = 'api_base_url';
  static const String autoUpload = 'auto_upload';
  static const String compressionEnabled = 'compression_enabled';
  static const String compressionQuality = 'compression_quality';
  static const String uploadHistory = 'upload_history';
  static const String lastSyncTime = 'last_sync_time';
  static const String darkMode = 'dark_mode';
  static const String notificationsEnabled = 'notifications_enabled';
}

// Error Messages
class ErrorMessages {
  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String fileNotFound = 'File not found.';
  static const String fileTooLarge = 'File is too large.';
  static const String unsupportedFileType = 'Unsupported file type.';
  static const String uploadFailed = 'Upload failed. Please try again.';
  static const String permissionDenied = 'Permission denied. Please grant file access permission.';
  static const String unknownError = 'An unknown error occurred.';
}

// Success Messages
class SuccessMessages {
  static const String uploadCompleted = 'Upload completed successfully!';
  static const String fileUploaded = 'File uploaded successfully!';
  static const String filesUploaded = 'Files uploaded successfully!';
  static const String connectionEstablished = 'Connection established!';
  static const String settingsSaved = 'Settings saved successfully!';
}

// File Type Utilities
class FileTypeUtils {
  static String getFileTypeFromExtension(String extension) {
    final ext = extension.toLowerCase();

    if (AppConstants.supportedImageTypes.contains(ext)) {
      return 'image';
    } else if (AppConstants.supportedVideoTypes.contains(ext)) {
      return 'video';
    } else if (AppConstants.supportedDocumentTypes.contains(ext)) {
      return 'document';
    } else {
      return 'file';
    }
  }

  static bool isImageFile(String extension) {
    return AppConstants.supportedImageTypes.contains(extension.toLowerCase());
  }

  static bool isVideoFile(String extension) {
    return AppConstants.supportedVideoTypes.contains(extension.toLowerCase());
  }

  static bool isDocumentFile(String extension) {
    return AppConstants.supportedDocumentTypes.contains(extension.toLowerCase());
  }
}

// Size Formatting Utilities
class SizeUtils {
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  static bool isFileSizeValid(int bytes, {bool isImage = false}) {
    if (isImage) {
      return bytes <= AppConstants.maxImageSize;
    } else {
      return bytes <= AppConstants.maxFileSize;
    }
  }
}