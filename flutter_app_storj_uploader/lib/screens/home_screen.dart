import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/file_upload_area.dart';
import '../widgets/upload_queue.dart';
import '../widgets/system_status_card.dart';
import '../widgets/connection_status.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/file_service.dart';
import '../models/api_models.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<LocalFile> _uploadQueue = [];
  bool _isConnected = false;
  StatusResponse? _systemStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkConnection();
    _loadSystemStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final connected = await ApiService().testConnection();
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _loadSystemStatus() async {
    if (!_isConnected) {
      print('DEBUG _loadSystemStatus: Not connected, skipping');
      return;
    }

    try {
      print('DEBUG _loadSystemStatus: Fetching status...');
      final status = await ApiService().getStatus();
      print('DEBUG _loadSystemStatus: Got status - storjServiceRunning: ${status.storjServiceRunning}');
      print('DEBUG _loadSystemStatus: uploadQueueCount: ${status.uploadQueueCount}, totalUploaded: ${status.totalUploaded}');
      if (mounted) {
        setState(() {
          _systemStatus = status;
        });
      }
    } catch (e) {
      print('Error loading system status: $e');
    }
  }

  void _addToQueue(List<LocalFile> files) {
    setState(() {
      _uploadQueue.addAll(files);
    });
  }

  void _removeFromQueue(LocalFile file) {
    setState(() {
      _uploadQueue.remove(file);
    });
  }

  void _clearQueue() {
    setState(() {
      _uploadQueue.clear();
    });
  }

  Future<void> _refreshStatus() async {
    await _checkConnection();
    await _loadSystemStatus();
  }

  Future<void> _triggerStorjUpload() async {
    if (!_isConnected) {
      _showSnackBar('Not connected to server', isError: true);
      return;
    }

    try {
      final response = await ApiService().triggerUploadAsync();
      _showSnackBar(response.message);
      await _loadSystemStatus();
    } catch (e) {
      _showSnackBar('Failed to trigger upload: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(UIConstants.errorColorValue)
            : const Color(UIConstants.successColorValue),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: 'Refresh Status',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _triggerStorjUpload,
            tooltip: 'Trigger Storj Upload',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              // If settings were changed, refresh connection
              if (result == true && mounted) {
                await _refreshStatus();
              }
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Upload'),
            Tab(icon: Icon(Icons.queue), text: 'Queue'),
            Tab(icon: Icon(Icons.info), text: 'Status'),
            Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection Status
          ConnectionStatus(
            isConnected: _isConnected,
            onRetry: _checkConnection,
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Upload Tab
                _buildUploadTab(),

                // Queue Tab
                _buildQueueTab(),

                // Status Tab
                _buildStatusTab(),

                // Gallery Tab
                const GalleryScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _uploadQueue.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _uploadQueue.isEmpty ? null : _startUpload,
              icon: const Icon(Icons.cloud_upload),
              label: Text('Upload (${_uploadQueue.length})'),
            )
          : null,
    );
  }

  Widget _buildUploadTab() {
    return Padding(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      child: Column(
        children: [
          // Upload Area
          Expanded(
            flex: 3,
            child: FileUploadArea(
              onFilesSelected: _addToQueue,
              isEnabled: _isConnected,
            ),
          ),

          const SizedBox(height: UIConstants.defaultPadding),

          // Quick Actions
          Expanded(
            flex: 1,
            child: _buildQuickActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UIConstants.smallPadding),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnected ? () => _pickFiles('images') : null,
                      icon: const Icon(Icons.image),
                      label: const Text('Images'),
                    ),
                  ),
                  const SizedBox(width: UIConstants.smallPadding),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnected ? () => _pickFiles('videos') : null,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Videos'),
                    ),
                  ),
                  const SizedBox(width: UIConstants.smallPadding),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnected ? () => _pickFiles('documents') : null,
                      icon: const Icon(Icons.description),
                      label: const Text('Documents'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return UploadQueue(
      files: _uploadQueue,
      onRemove: _removeFromQueue,
      onClear: _clearQueue,
    );
  }

  Widget _buildStatusTab() {
    return Padding(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      child: Column(
        children: [
          // System Status Card
          SystemStatusCard(
            status: _systemStatus,
            isConnected: _isConnected,
            onRefresh: _loadSystemStatus,
          ),

          const SizedBox(height: UIConstants.defaultPadding),

          // Upload Statistics (placeholder)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Statistics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: UIConstants.smallPadding),
                  if (_systemStatus != null) ...[
                    _buildStatItem('Queue Count', '${_systemStatus!.uploadQueueCount}'),
                    _buildStatItem('Total Uploaded', '${_systemStatus!.totalUploaded}'),
                    _buildStatItem('Last Upload', _systemStatus!.lastUploadTime.isNotEmpty
                        ? _systemStatus!.lastUploadTime
                        : 'Never'),
                    _buildStatItem('Storj Service', _systemStatus!.storjServiceRunning
                        ? 'Running'
                        : 'Stopped'),
                  ] else
                    const Text('No statistics available'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles(String type) async {
    if (!_isConnected) {
      _showSnackBar('Not connected to server', isError: true);
      return;
    }

    try {
      List<LocalFile> files = [];

      switch (type) {
        case 'images':
          files = await FileService().pickMultipleImages();
          break;
        case 'videos':
          final video = await FileService().pickVideoFromGallery();
          if (video != null) files = [video];
          break;
        case 'documents':
          files = await FileService().pickDocuments();
          break;
        default:
          files = await FileService().pickFiles();
      }

      if (files.isNotEmpty) {
        _addToQueue(files);
        _showSnackBar('Added ${files.length} file${files.length == 1 ? '' : 's'} to queue');
      }
    } catch (e) {
      _showSnackBar('Failed to pick files: $e', isError: true);
    }
  }

  Future<void> _startUpload() async {
    if (_uploadQueue.isEmpty || !_isConnected) return;

    try {
      _showSnackBar('Upload started for ${_uploadQueue.length} files');

      // Upload files in batches to avoid overwhelming the server
      const batchSize = 5;
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < _uploadQueue.length; i += batchSize) {
        final batch = _uploadQueue.skip(i).take(batchSize).toList();

        for (final localFile in batch) {
          try {
            // Web platform uses byte data instead of File I/O
            if (kIsWeb) {
              final isImage = FileTypeUtils.isImageFile(
                localFile.name.split('.').last.toLowerCase(),
              );

              if (localFile.webFile != null) {
                print('Uploading file from browser FormData: ${localFile.name}');
                await ApiService().uploadFromBrowserFile(
                  localFile.webFile!,
                  isImage: isImage,
                );
                successCount++;
                continue;
              }

              // Fallback to in-memory bytes when browser file is unavailable
              if (localFile.bytes == null) {
                throw Exception('File data not available for web upload: ${localFile.name}');
              }

              print('Uploading file from bytes: ${localFile.name}');
              await ApiService().uploadFromBytes(
                localFile.bytes!,
                localFile.name,
              );
              successCount++;
            } else {
              // For non-web platforms, use file path
              final file = File(localFile.path);

              // Validate file still exists
              if (!await file.exists()) {
                throw Exception('File not found: ${localFile.name}');
              }

              // Determine upload method based on file type
              final isImage = FileTypeUtils.isImageFile(
                localFile.name.split('.').last.toLowerCase()
              );

              print('Uploading file from path: ${localFile.name}');
              if (isImage) {
                await ApiService().uploadSingleImage(file);
              } else {
                await ApiService().uploadSingleFile(file);
              }
              successCount++;
            }
          } catch (e) {
            print('Failed to upload ${localFile.name}: $e');
            failCount++;
          }
        }

        // Small delay between batches
        if (i + batchSize < _uploadQueue.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Clear queue after upload attempt
      _clearQueue();

      // Show result
      if (failCount == 0) {
        _showSnackBar('Successfully uploaded $successCount files!');
      } else if (successCount == 0) {
        _showSnackBar('Failed to upload all files', isError: true);
      } else {
        _showSnackBar('Uploaded $successCount files, $failCount failed', isError: true);
      }

      // Refresh system status to see updated counts
      await _loadSystemStatus();
    } catch (e) {
      _showSnackBar('Upload failed: $e', isError: true);
    }
  }
}
