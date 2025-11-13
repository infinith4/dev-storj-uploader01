import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import '../models/api_models.dart';
import '../utils/constants.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Pick single image from camera
  Future<LocalFile?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await _createLocalFileFromXFile(pickedFile);
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    }
    return null;
  }

  // Pick single image from gallery
  Future<LocalFile?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await _createLocalFileFromXFile(pickedFile);
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
    }
    return null;
  }

  // Pick multiple images from gallery
  Future<List<LocalFile>> pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      final List<LocalFile> localFiles = [];
      for (final file in pickedFiles) {
        final localFile = await _createLocalFileFromXFile(file);
        if (localFile != null) {
          localFiles.add(localFile);
        }
      }
      return localFiles;
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }

  // Pick single video
  Future<LocalFile?> pickVideoFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (pickedFile != null) {
        return await _createLocalFileFromXFile(pickedFile);
      }
    } catch (e) {
      print('Error picking video from camera: $e');
    }
    return null;
  }

  // Pick single video from gallery
  Future<LocalFile?> pickVideoFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (pickedFile != null) {
        return await _createLocalFileFromXFile(pickedFile);
      }
    } catch (e) {
      print('Error picking video from gallery: $e');
    }
    return null;
  }

  // Pick multiple videos from gallery
  Future<List<LocalFile>> pickMultipleVideos() async {
    try {
      // Use file picker for multiple video selection
      return await pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
    } catch (e) {
      print('Error picking multiple videos: $e');
      return [];
    }
  }

  // Pick any file type
  Future<List<LocalFile>> pickFiles({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    bool allowMultiple = true,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: false,
        withReadStream: false,
      );

      if (result != null) {
        final List<LocalFile> localFiles = [];
        for (final file in result.files) {
          if (file.path != null) {
            final localFile = await _createLocalFileFromPlatformFile(file);
            if (localFile != null) {
              localFiles.add(localFile);
            }
          }
        }
        return localFiles;
      }
    } catch (e) {
      print('Error picking files: $e');
    }
    return [];
  }

  // Pick documents only
  Future<List<LocalFile>> pickDocuments({bool allowMultiple = true}) async {
    return await pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedDocumentTypes,
      allowMultiple: allowMultiple,
    );
  }

  // Create LocalFile from XFile (ImagePicker)
  Future<LocalFile?> _createLocalFileFromXFile(XFile xFile) async {
    try {
      final int fileSize;
      if (kIsWeb) {
        // For web, get file size from XFile directly
        fileSize = await xFile.length();
      } else {
        final File file = File(xFile.path);
        fileSize = await file.length();
      }
      final String fileName = xFile.name;
      final String? mimeType = xFile.mimeType ?? lookupMimeType(xFile.path);

      // Validate file size
      final bool isImage = FileTypeUtils.isImageFile(_getFileExtension(fileName));
      if (!SizeUtils.isFileSizeValid(fileSize, isImage: isImage)) {
        throw Exception(isImage ?
          'Image file is too large (max ${SizeUtils.formatBytes(AppConstants.maxImageSize)})' :
          'File is too large (max ${SizeUtils.formatBytes(AppConstants.maxFileSize)})'
        );
      }

      return LocalFile(
        id: _uuid.v4(),
        name: fileName,
        path: xFile.path,
        size: fileSize,
        type: mimeType ?? 'application/octet-stream',
        dateAdded: DateTime.now(),
      );
    } catch (e) {
      print('Error creating LocalFile from XFile: $e');
      return null;
    }
  }

  // Create LocalFile from PlatformFile (FilePicker)
  Future<LocalFile?> _createLocalFileFromPlatformFile(PlatformFile platformFile) async {
    try {
      if (platformFile.path == null) return null;

      final File file = File(platformFile.path!);
      final int fileSize = platformFile.size;
      final String fileName = platformFile.name;
      final String? mimeType = lookupMimeType(platformFile.path!);

      // Validate file size
      final bool isImage = FileTypeUtils.isImageFile(_getFileExtension(fileName));
      if (!SizeUtils.isFileSizeValid(fileSize, isImage: isImage)) {
        throw Exception(isImage ?
          'Image file is too large (max ${SizeUtils.formatBytes(AppConstants.maxImageSize)})' :
          'File is too large (max ${SizeUtils.formatBytes(AppConstants.maxFileSize)})'
        );
      }

      return LocalFile(
        id: _uuid.v4(),
        name: fileName,
        path: platformFile.path!,
        size: fileSize,
        type: mimeType ?? 'application/octet-stream',
        dateAdded: DateTime.now(),
      );
    } catch (e) {
      print('Error creating LocalFile from PlatformFile: $e');
      return null;
    }
  }

  // Create LocalFile from bytes (for web/memory)
  Future<LocalFile?> createLocalFileFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final String tempPath;

      if (kIsWeb) {
        // For web, create a virtual path
        tempPath = 'web_file_${_uuid.v4()}_$fileName';
      } else {
        // Save bytes to temporary file for non-web platforms
        final Directory tempDir = await getTemporaryDirectory();
        tempPath = '${tempDir.path}/${_uuid.v4()}_$fileName';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(bytes);
      }

      final String? mimeType = lookupMimeType(fileName);
      final bool isImage = FileTypeUtils.isImageFile(_getFileExtension(fileName));

      // Validate file size
      if (!SizeUtils.isFileSizeValid(bytes.length, isImage: isImage)) {
        if (!kIsWeb) {
          final File tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete(); // Clean up
          }
        }
        throw Exception(isImage ?
          'Image file is too large (max ${SizeUtils.formatBytes(AppConstants.maxImageSize)})' :
          'File is too large (max ${SizeUtils.formatBytes(AppConstants.maxFileSize)})'
        );
      }

      return LocalFile(
        id: _uuid.v4(),
        name: fileName,
        path: tempPath,
        size: bytes.length,
        type: mimeType ?? 'application/octet-stream',
        dateAdded: DateTime.now(),
      );
    } catch (e) {
      print('Error creating LocalFile from bytes: $e');
      return null;
    }
  }

  // Get file extension
  String _getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  // Generate thumbnail for image files
  Future<String?> generateImageThumbnail(LocalFile localFile) async {
    try {
      if (!FileTypeUtils.isImageFile(_getFileExtension(localFile.name))) {
        return null;
      }

      // For web platform, we return the path as-is
      // For non-web platforms, we could generate actual thumbnails
      if (kIsWeb) {
        // On web, just return the virtual path
        return localFile.path;
      }

      // For simplicity, we return the original file path
      // In a real app, you might want to generate actual thumbnails
      return localFile.path;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  // Delete temporary file
  Future<void> deleteFile(String filePath) async {
    if (kIsWeb) {
      // Web doesn't support file deletion in the same way
      print('File deletion not supported on web platform');
      return;
    }

    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  // Clean up temporary files
  Future<void> cleanupTempFiles() async {
    if (kIsWeb) {
      // Web doesn't support directory operations in the same way
      print('Temp file cleanup not supported on web platform');
      return;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> entities = tempDir.listSync();

      for (final entity in entities) {
        if (entity is File) {
          final String fileName = entity.path.split('/').last;
          // Delete files that match our temporary file pattern
          if (fileName.contains(_uuid.v4().substring(0, 8))) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }

  // Validate file before upload
  bool validateFile(LocalFile localFile) {
    // For web, we can't check file existence in the same way
    if (kIsWeb) {
      // On web, just validate file size
      final bool isImage = FileTypeUtils.isImageFile(_getFileExtension(localFile.name));
      return SizeUtils.isFileSizeValid(localFile.size, isImage: isImage);
    }

    // Check file exists (non-web platforms)
    if (!File(localFile.path).existsSync()) {
      return false;
    }

    // Check file size
    final bool isImage = FileTypeUtils.isImageFile(_getFileExtension(localFile.name));
    if (!SizeUtils.isFileSizeValid(localFile.size, isImage: isImage)) {
      return false;
    }

    return true;
  }

  // Get file icon based on type
  String getFileIcon(LocalFile localFile) {
    final String extension = _getFileExtension(localFile.name);

    if (FileTypeUtils.isImageFile(extension)) {
      return 'image';
    } else if (FileTypeUtils.isVideoFile(extension)) {
      return 'video';
    } else if (FileTypeUtils.isDocumentFile(extension)) {
      return 'document';
    } else {
      return 'file';
    }
  }
}