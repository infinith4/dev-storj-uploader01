import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import '../models/api_models.dart';
import '../services/file_service.dart';
import '../utils/constants.dart';

class FileUploadArea extends StatefulWidget {
  final Function(List<LocalFile>) onFilesSelected;
  final bool isEnabled;

  const FileUploadArea({
    super.key,
    required this.onFilesSelected,
    required this.isEnabled,
  });

  @override
  State<FileUploadArea> createState() => _FileUploadAreaState();
}

class _FileUploadAreaState extends State<FileUploadArea>
    with TickerProviderStateMixin {
  bool _isDragOver = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  DropzoneViewController? _dropzoneController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: UIConstants.fastAnimationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (!widget.isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      final files = await FileService().pickFiles();
      if (files.isNotEmpty) {
        widget.onFilesSelected(files);
        _showSuccessAnimation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick files: $e');
    }
  }

  Future<void> _pickImages() async {
    if (!widget.isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      final files = await FileService().pickMultipleImages();
      if (files.isNotEmpty) {
        widget.onFilesSelected(files);
        _showSuccessAnimation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick images: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (!widget.isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      final file = await FileService().pickImageFromCamera();
      if (file != null) {
        widget.onFilesSelected([file]);
        _showSuccessAnimation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _pickVideoFromCamera() async {
    if (!widget.isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      final file = await FileService().pickVideoFromCamera();
      if (file != null) {
        widget.onFilesSelected([file]);
        _showSuccessAnimation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to record video: $e');
    }
  }

  Future<void> _pickMultipleVideos() async {
    if (!widget.isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      final files = await FileService().pickMultipleVideos();
      if (files.isNotEmpty) {
        widget.onFilesSelected(files);
        _showSuccessAnimation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick videos: $e');
    }
  }

  void _showSuccessAnimation() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(UIConstants.errorColorValue),
      ),
    );
  }

  void _onDragEnter() {
    if (!widget.isEnabled) return;
    setState(() {
      _isDragOver = true;
    });
    _animationController.forward();
  }

  void _onDragLeave() {
    setState(() {
      _isDragOver = false;
    });
    _animationController.reverse();
  }

  Future<void> _onDrop(dynamic event) async {
    if (!widget.isEnabled) return;

    if (_dropzoneController == null) {
      print('ERROR: _dropzoneController is null in _onDrop');
      _showErrorSnackBar('File upload controller not initialized');
      return;
    }

    setState(() {
      _isDragOver = false;
    });
    _animationController.reverse();

    try {
      // Get file info with null safety
      final controller = _dropzoneController;
      if (controller == null) {
        print('ERROR: _dropzoneController became null during _onDrop');
        _showErrorSnackBar('File upload controller not available');
        return;
      }

      print('DEBUG: Getting filename...');
      String? name;
      int? size;
      String? mimeType;

      try {
        name = await controller.getFilename(event);
        print('DEBUG: Filename result: $name');
      } catch (e) {
        print('ERROR: Exception in getFilename: $e');
        _showErrorSnackBar('Failed to get file name: $e');
        return;
      }

      if (name == null || name.isEmpty) {
        print('ERROR: getFilename returned null or empty');
        _showErrorSnackBar('Could not get file name');
        return;
      }
      print('DEBUG: Filename: $name');

      print('DEBUG: Getting file size...');
      try {
        size = await controller.getFileSize(event);
        print('DEBUG: Size result: $size');
      } catch (e) {
        print('ERROR: Exception in getFileSize: $e');
        _showErrorSnackBar('Failed to get file size: $e');
        return;
      }

      if (size == null) {
        print('ERROR: getFileSize returned null');
        _showErrorSnackBar('Could not get file size');
        return;
      }
      print('DEBUG: File size: $size');

      print('DEBUG: Getting MIME type...');
      try {
        mimeType = await controller.getFileMIME(event);
        print('DEBUG: MIME type result: $mimeType');
      } catch (e) {
        print('ERROR: Exception in getFileMIME: $e');
        _showErrorSnackBar('Failed to get file type: $e');
        return;
      }

      if (mimeType == null || mimeType.isEmpty) {
        print('ERROR: getFileMIME returned null or empty');
        _showErrorSnackBar('Could not get file type');
        return;
      }
      print('DEBUG: MIME type: $mimeType');

      print('Processing dropped file: $name (${SizeUtils.formatBytes(size)})');

      // Validate file size
      final isImage = mimeType.startsWith('image/');
      final maxSize = isImage ? AppConstants.maxImageSize : AppConstants.maxFileSize;

      if (size > maxSize) {
        _showErrorSnackBar(
          'File too large: ${SizeUtils.formatBytes(size)}. Max: ${SizeUtils.formatBytes(maxSize)}'
        );
        return;
      }

      // Get file data (bytes) - returns Uint8List
      print('Getting file data for $name...');
      final Uint8List? bytes = await controller.getFileData(event);

      if (bytes == null) {
        print('ERROR: getFileData returned null for file: $name');
        _showErrorSnackBar('Failed to read file data: $name');
        return;
      }

      print('File data loaded: ${bytes.length} bytes');

      // Create LocalFile using FileService
      print('Creating LocalFile from bytes...');
      final localFile = await FileService().createLocalFileFromBytes(bytes, name);

      if (localFile != null) {
        print('LocalFile created successfully: ${localFile.name}');
        widget.onFilesSelected([localFile]);
        _showSuccessAnimation();
      } else {
        print('ERROR: createLocalFileFromBytes returned null for file: $name');
        _showErrorSnackBar('Failed to process file: $name');
      }
    } catch (e, stackTrace) {
      _showErrorSnackBar('Failed to process dropped file: $e');
      print('Drop error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _onDropMultiple(List<dynamic>? events) async {
    if (!widget.isEnabled || events == null || events.isEmpty) return;

    if (_dropzoneController == null) {
      print('ERROR: _dropzoneController is null in _onDropMultiple');
      _showErrorSnackBar('File upload controller not initialized');
      return;
    }

    setState(() {
      _isDragOver = false;
    });
    _animationController.reverse();

    try {
      final localFiles = <LocalFile>[];
      final controller = _dropzoneController;
      if (controller == null) {
        print('ERROR: _dropzoneController became null during _onDropMultiple');
        _showErrorSnackBar('File upload controller not available');
        return;
      }

      print('Processing ${events.length} dropped files');

      for (var event in events) {
        try {
          print('DEBUG: Processing individual file from multiple drop...');

          String? name;
          int? size;
          String? mimeType;

          try {
            name = await controller.getFilename(event);
            print('DEBUG: Filename result: $name');
          } catch (e) {
            print('ERROR: Exception in getFilename: $e');
            continue;
          }

          if (name == null || name.isEmpty) {
            print('ERROR: getFilename returned null or empty for one file');
            continue;
          }
          print('DEBUG: Filename: $name');

          try {
            size = await controller.getFileSize(event);
            print('DEBUG: Size result for $name: $size');
          } catch (e) {
            print('ERROR: Exception in getFileSize for $name: $e');
            continue;
          }

          if (size == null) {
            print('ERROR: getFileSize returned null for file: $name');
            continue;
          }
          print('DEBUG: File size for $name: $size');

          try {
            mimeType = await controller.getFileMIME(event);
            print('DEBUG: MIME type result for $name: $mimeType');
          } catch (e) {
            print('ERROR: Exception in getFileMIME for $name: $e');
            continue;
          }

          if (mimeType == null || mimeType.isEmpty) {
            print('ERROR: getFileMIME returned null or empty for file: $name');
            continue;
          }
          print('DEBUG: MIME type for $name: $mimeType');

          print('Processing file: $name (${SizeUtils.formatBytes(size)})');

          // Validate file size
          final isImage = mimeType.startsWith('image/');
          final maxSize = isImage ? AppConstants.maxImageSize : AppConstants.maxFileSize;

          if (size > maxSize) {
            print('Skipping file $name: too large (${SizeUtils.formatBytes(size)})');
            continue;
          }

          // Get file data (bytes) - returns Uint8List
          print('Getting file data for $name...');
          final Uint8List? bytes = await controller.getFileData(event);

          if (bytes == null) {
            print('ERROR: getFileData returned null for file: $name');
            continue;
          }

          print('File data loaded for $name: ${bytes.length} bytes');

          // Create LocalFile using FileService
          print('Creating LocalFile from bytes...');
          final localFile = await FileService().createLocalFileFromBytes(bytes, name);

          if (localFile != null) {
            print('LocalFile created: ${localFile.name}');
            localFiles.add(localFile);
          } else {
            print('ERROR: createLocalFileFromBytes returned null for file: $name');
          }
        } catch (e, stackTrace) {
          print('Error processing file: $e');
          print('Stack trace: $stackTrace');
        }
      }

      if (localFiles.isNotEmpty) {
        print('Successfully processed ${localFiles.length} files');
        widget.onFilesSelected(localFiles);
        _showSuccessAnimation();
      } else {
        _showErrorSnackBar('No files could be processed');
      }
    } catch (e, stackTrace) {
      _showErrorSnackBar('Failed to process dropped files: $e');
      print('Drop multiple error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String _getFileTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('application/pdf') ||
        mimeType.contains('document') ||
        mimeType.contains('text')) return 'document';
    return 'file';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragOver
                    ? const Color(UIConstants.primaryColorValue)
                    : Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(UIConstants.largeBorderRadius),
              color: widget.isEnabled
                  ? (_isDragOver ? Colors.blue.shade50 : Colors.grey.shade50)
                  : Colors.grey.shade100,
            ),
            child: widget.isEnabled ? _buildEnabledContent() : _buildDisabledContent(),
          ),
        );
      },
    );
  }

  Widget _buildEnabledContent() {
    // For web platform, use DropzoneView for drag and drop
    if (kIsWeb) {
      return Stack(
        children: [
          DropzoneView(
            onCreated: (controller) => _dropzoneController = controller,
            onHover: () => _onDragEnter(),
            onLeave: () => _onDragLeave(),
            onDrop: _onDrop,
            onDropMultiple: _onDropMultiple,
            operation: DragOperation.copy,
          ),
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(UIConstants.largeBorderRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(UIConstants.largePadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDragOver ? Icons.cloud_upload : Icons.cloud_upload_outlined,
                    size: 64,
                    color: _isDragOver
                        ? const Color(UIConstants.primaryColorValue)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(height: UIConstants.defaultPadding),
                  Text(
                    _isDragOver
                        ? 'Drop files here'
                        : 'Tap to select files or drag & drop',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _isDragOver
                          ? const Color(UIConstants.primaryColorValue)
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: UIConstants.smallPadding),
                  Text(
                    'Supported: Images, Videos, Documents',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: UIConstants.largePadding),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // For non-web platforms, use standard InkWell
    return InkWell(
      onTap: _pickFiles,
      borderRadius: BorderRadius.circular(UIConstants.largeBorderRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(UIConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDragOver ? Icons.cloud_upload : Icons.cloud_upload_outlined,
              size: 64,
              color: _isDragOver
                  ? const Color(UIConstants.primaryColorValue)
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: UIConstants.defaultPadding),
            Text(
              _isDragOver
                  ? 'Drop files here'
                  : 'Tap to select files',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _isDragOver
                    ? const Color(UIConstants.primaryColorValue)
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UIConstants.smallPadding),
            Text(
              'Supported: Images, Videos, Documents',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UIConstants.largePadding),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UIConstants.largePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: UIConstants.defaultPadding),
          Text(
            'Not connected to server',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UIConstants.smallPadding),
          Text(
            'Please check your connection and try again',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: UIConstants.smallPadding,
      runSpacing: UIConstants.smallPadding,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.photo_library, size: UIConstants.smallIconSize),
          label: const Text('Images'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallPadding,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _pickMultipleVideos,
          icon: const Icon(Icons.video_library, size: UIConstants.smallIconSize),
          label: const Text('Videos'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallPadding,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _pickImageFromCamera,
          icon: const Icon(Icons.camera_alt, size: UIConstants.smallIconSize),
          label: const Text('Camera'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallPadding,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _pickVideoFromCamera,
          icon: const Icon(Icons.videocam, size: UIConstants.smallIconSize),
          label: const Text('Record'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallPadding,
            ),
          ),
        ),
      ],
    );
  }
}