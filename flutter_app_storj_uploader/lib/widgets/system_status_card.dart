import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_models.dart';
import '../utils/constants.dart';

class SystemStatusCard extends StatelessWidget {
  final StatusResponse? status;
  final bool isConnected;
  final VoidCallback? onRefresh;

  const SystemStatusCard({
    super.key,
    required this.status,
    required this.isConnected,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: UIConstants.defaultPadding),
            if (isConnected && status != null)
              _buildStatusContent(context)
            else
              _buildDisconnectedContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          isConnected ? Icons.cloud_done : Icons.cloud_off,
          color: isConnected
              ? const Color(UIConstants.successColorValue)
              : const Color(UIConstants.errorColorValue),
          size: UIConstants.defaultIconSize,
        ),
        const SizedBox(width: UIConstants.smallPadding),
        Expanded(
          child: Text(
            'System Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRefresh!();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            iconSize: UIConstants.defaultIconSize,
          ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context) {
    return Column(
      children: [
        _buildStatusIndicator(context),
        const SizedBox(height: UIConstants.defaultPadding),
        _buildStatusDetails(context),
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final bool storjRunning = status?.storjServiceRunning ?? false;
    final Color statusColor = storjRunning
        ? const Color(UIConstants.successColorValue)
        : const Color(UIConstants.errorColorValue);

    return Container(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: UIConstants.smallPadding),
          Expanded(
            child: Text(
              storjRunning ? 'Storj Service Running' : 'Storj Service Stopped',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
          if (storjRunning)
            Icon(
              Icons.check_circle,
              color: statusColor,
              size: UIConstants.defaultIconSize,
            )
          else
            Icon(
              Icons.error,
              color: statusColor,
              size: UIConstants.defaultIconSize,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDetails(BuildContext context) {
    return Column(
      children: [
        _buildDetailRow(
          context,
          'Upload Queue',
          '${status!.uploadQueueCount} files',
          Icons.queue,
          status!.uploadQueueCount > 0
              ? const Color(UIConstants.warningColorValue)
              : Colors.grey.shade600,
        ),
        _buildDetailRow(
          context,
          'Total Uploaded',
          '${status!.totalUploaded} files',
          Icons.cloud_upload,
          const Color(UIConstants.primaryColorValue),
        ),
        _buildDetailRow(
          context,
          'Last Upload',
          status!.lastUploadTime.isNotEmpty
              ? _formatLastUpload(status!.lastUploadTime)
              : 'Never',
          Icons.schedule,
          Colors.grey.shade600,
        ),
        _buildDetailRow(
          context,
          'Server Time',
          _formatServerTime(),
          Icons.access_time,
          Colors.grey.shade600,
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UIConstants.smallPadding),
      child: Row(
        children: [
          Icon(
            icon,
            size: UIConstants.smallIconSize,
            color: color,
          ),
          const SizedBox(width: UIConstants.smallPadding),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          decoration: BoxDecoration(
            color: const Color(UIConstants.errorColorValue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
            border: Border.all(
              color: const Color(UIConstants.errorColorValue).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                color: const Color(UIConstants.errorColorValue),
                size: UIConstants.defaultIconSize,
              ),
              const SizedBox(width: UIConstants.smallPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Connection',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: const Color(UIConstants.errorColorValue),
                      ),
                    ),
                    Text(
                      'Unable to connect to server',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(UIConstants.errorColorValue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: UIConstants.defaultPadding),
        _buildTroubleshootingTips(context),
      ],
    );
  }

  Widget _buildTroubleshootingTips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Troubleshooting',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: UIConstants.smallPadding),
          _buildTipItem(context, 'Check if the server is running'),
          _buildTipItem(context, 'Verify network connection'),
          _buildTipItem(context, 'Ensure correct server URL in settings'),
          _buildTipItem(context, 'Try refreshing the connection'),
        ],
      ),
    );
  }

  Widget _buildTipItem(BuildContext context, String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpload(String lastUploadTime) {
    try {
      final date = DateTime.parse(lastUploadTime);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return lastUploadTime;
    }
  }

  String _formatServerTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}