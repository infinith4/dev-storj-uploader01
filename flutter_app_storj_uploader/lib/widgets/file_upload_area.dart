import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'dart:html' as html;
import 'package:uuid/uuid.dart';
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
  bool _dropInProgress = false;
  final Uuid _uuid = const Uuid();

  void _scheduleDropReset() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _dropInProgress = false;
    });
  }

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
    if (_dropInProgress) return;
    _dropInProgress = true;

    setState(() {
      _isDragOver = false;
    });
    _animationController.reverse();

    try {
      // Handle HTML File object directly (Web platform)
      if (kIsWeb && event is html.File) {
        print('DEBUG: Processing HTML File object directly');
        await _processHtmlFile(event);
        return;
      }

      // Fallback to dropzone controller methods
      if (_dropzoneController == null) {
        print('ERROR: _dropzoneController is null');
        _showErrorSnackBar('File upload controller not initialized');
        return;
      }

      final controller = _dropzoneController!;
      print('DEBUG: Using dropzone controller methods');

      final name = await controller.getFilename(event);
      final size = await controller.getFileSize(event);
      final mimeType = await controller.getFileMIME(event);

      if (name == null || size == null || mimeType == null) {
        print('ERROR: Could not get file info');
        _showErrorSnackBar('Could not get file information');
        return;
      }

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

      // Get file data
      final bytes = await controller.getFileData(event);
      if (bytes == null) {
        print('ERROR: getFileData returned null');
        _showErrorSnackBar('Failed to read file data');
        return;
      }

      // Create LocalFile
      final localFile = await FileService().createLocalFileFromBytes(bytes, name);
      if (localFile != null) {
        widget.onFilesSelected([localFile]);
        _showSuccessAnimation();
      }
    } catch (e, stackTrace) {
      _showErrorSnackBar('Failed to process dropped file: $e');
      print('Drop error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _scheduleDropReset();
    }
  }

  Future<void> _processHtmlFile(html.File file) async {
    try {
      final name = file.name;
      final size = file.size;
      final mimeType = file.type;

      print('DEBUG: HTML File - Name: $name, Size: $size, Type: $mimeType');

      // Validate file size
      final isImage = mimeType.startsWith('image/');
      final maxSize = isImage ? AppConstants.maxImageSize : AppConstants.maxFileSize;

      if (size > maxSize) {
        _showErrorSnackBar(
          'File too large: ${SizeUtils.formatBytes(size)}. Max: ${SizeUtils.formatBytes(maxSize)}'
        );
        return;
      }

      final id = _uuid.v4();
      final localFile = LocalFile(
        id: id,
        name: name,
        path: 'web_file_${id}_$name',
        size: size,
        type: mimeType.isNotEmpty ? mimeType : 'application/octet-stream',
        dateAdded: DateTime.now(),
        webFile: file,
      );

      print('LocalFile created successfully: ${localFile.name}');
      widget.onFilesSelected([localFile]);
      _showSuccessAnimation();
    } catch (e, stackTrace) {
      print('ERROR processing HTML file: $e');
      print('Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to process file: $e');
    }
  }

  Future<void> _onDropMultiple(List<dynamic>? events) async {
    if (!widget.isEnabled || events == null || events.isEmpty) return;
    if (_dropInProgress) return;
    _dropInProgress = true;

    setState(() {
      _isDragOver = false;
    });
    _animationController.reverse();

    try {
      final localFiles = <LocalFile>[];
      print('Processing ${events.length} dropped files');

      for (var event in events) {
        try {
          // Handle HTML File object directly (Web platform)
          if (kIsWeb && event is html.File) {
            print('DEBUG: Processing HTML File object: ${event.name}');
            final localFile = await _processHtmlFileAndReturn(event);
            if (localFile != null) {
              localFiles.add(localFile);
            }
            continue;
          }

          // Fallback to dropzone controller methods
          if (_dropzoneController == null) {
            print('ERROR: _dropzoneController is null, skipping file');
            continue;
          }

          final controller = _dropzoneController!;
          final name = await controller.getFilename(event);
          final size = await controller.getFileSize(event);
          final mimeType = await controller.getFileMIME(event);

          if (name == null || size == null || mimeType == null) {
            print('ERROR: Could not get file info, skipping');
            continue;
          }

          // Validate file size
          final isImage = mimeType.startsWith('image/');
          final maxSize = isImage ? AppConstants.maxImageSize : AppConstants.maxFileSize;

          if (size > maxSize) {
            print('Skipping file $name: too large');
            continue;
          }

          // Get file data
          final bytes = await controller.getFileData(event);
          if (bytes == null) {
            print('ERROR: getFileData returned null for $name');
            continue;
          }

          // Create LocalFile
          final localFile = await FileService().createLocalFileFromBytes(bytes, name);
          if (localFile != null) {
            localFiles.add(localFile);
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
    } finally {
      _scheduleDropReset();
    }
  }

  Future<LocalFile?> _processHtmlFileAndReturn(html.File file) async {
    try {
      final name = file.name;
      final size = file.size;
      final mimeType = file.type;

      // Validate file size
      final isImage = mimeType.startsWith('image/');
      final maxSize = isImage ? AppConstants.maxImageSize : AppConstants.maxFileSize;

      if (size > maxSize) {
        print('Skipping file $name: too large');
        return null;
      }

      final id = _uuid.v4();
      return LocalFile(
        id: id,
        name: name,
        path: 'web_file_${id}_$name',
        size: size,
        type: mimeType.isNotEmpty ? mimeType : 'application/octet-stream',
        dateAdded: DateTime.now(),
        webFile: file,
      );
    } catch (e) {
      print('ERROR processing HTML file: $e');
      return null;
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
