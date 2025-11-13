import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_models.dart';
import '../utils/constants.dart';

class UploadQueue extends StatelessWidget {
  final List<LocalFile> files;
  final Function(LocalFile) onRemove;
  final VoidCallback onClear;

  const UploadQueue({
    super.key,
    required this.files,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: UIConstants.smallPadding),
        Expanded(
          child: _buildFileList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: UIConstants.defaultPadding),
          Text(
            'No files in queue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: UIConstants.smallPadding),
          Text(
            'Add files from the Upload tab to see them here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Row(
          children: [
            Icon(
              Icons.queue,
              color: const Color(UIConstants.primaryColorValue),
              size: UIConstants.defaultIconSize,
            ),
            const SizedBox(width: UIConstants.smallPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Queue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${files.length} file${files.length == 1 ? '' : 's'} • ${_getTotalSize()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (files.isNotEmpty) ...[
              IconButton(
                onPressed: () => _showClearConfirmation(context),
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear all',
                color: const Color(UIConstants.errorColorValue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: UIConstants.defaultPadding),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _buildFileItem(context, file, index);
      },
    );
  }

  Widget _buildFileItem(BuildContext context, LocalFile file, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: UIConstants.smallPadding),
      child: ListTile(
        leading: _buildFileIcon(file),
        title: Text(
          file.name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SizeUtils.formatBytes(file.size),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Added: ${_formatDate(file.dateAdded)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${index + 1}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: UIConstants.smallPadding),
            IconButton(
              onPressed: () => _removeFile(context, file),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove',
              color: const Color(UIConstants.errorColorValue),
              iconSize: UIConstants.defaultIconSize,
            ),
          ],
        ),
        onTap: () => _showFileDetails(context, file),
      ),
    );
  }

  Widget _buildFileIcon(LocalFile file) {
    IconData iconData;
    Color color;

    final extension = file.name.split('.').last.toLowerCase();

    if (FileTypeUtils.isImageFile(extension)) {
      iconData = Icons.image;
      color = Colors.blue;
    } else if (FileTypeUtils.isVideoFile(extension)) {
      iconData = Icons.videocam;
      color = Colors.red;
    } else if (FileTypeUtils.isDocumentFile(extension)) {
      iconData = Icons.description;
      color = Colors.orange;
    } else {
      iconData = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
      ),
      child: Icon(
        iconData,
        color: color,
        size: UIConstants.defaultIconSize,
      ),
    );
  }

  String _getTotalSize() {
    final totalBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    return SizeUtils.formatBytes(totalBytes);
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _removeFile(BuildContext context, LocalFile file) {
    HapticFeedback.lightImpact();
    onRemove(file);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${file.name}'),
        backgroundColor: const Color(UIConstants.successColorValue),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // Note: In a real app, you'd need to implement undo functionality
          },
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Queue'),
          content: Text(
            'Are you sure you want to remove all ${files.length} files from the queue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                HapticFeedback.mediumImpact();
                onClear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Queue cleared'),
                    backgroundColor: Color(UIConstants.successColorValue),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(UIConstants.errorColorValue),
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  void _showFileDetails(BuildContext context, LocalFile file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIConstants.largeBorderRadius),
        ),
      ),
      builder: (context) => _FileDetailsSheet(file: file),
    );
  }
}

class _FileDetailsSheet extends StatelessWidget {
  final LocalFile file;

  const _FileDetailsSheet({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: UIConstants.defaultPadding),

          // File name
          Text(
            'File Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: UIConstants.defaultPadding),

          // Details
          _buildDetailRow(context, 'Name', file.name),
          _buildDetailRow(context, 'Size', SizeUtils.formatBytes(file.size)),
          _buildDetailRow(context, 'Type', file.type),
          _buildDetailRow(context, 'Added', _formatFullDate(file.dateAdded)),
          _buildDetailRow(context, 'Path', file.path),

          const SizedBox(height: UIConstants.largePadding),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UIConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: UIConstants.defaultPadding),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}