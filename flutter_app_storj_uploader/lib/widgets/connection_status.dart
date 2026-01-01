import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class ConnectionStatus extends StatefulWidget {
  final bool isConnected;
  final VoidCallback? onRetry;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
    this.onRetry,
  });

  @override
  State<ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideController = AnimationController(
      duration: UIConstants.defaultAnimationDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _updateAnimations();
  }

  @override
  void didUpdateWidget(ConnectionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isConnected != widget.isConnected) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.isConnected) {
      _pulseController.stop();
      _slideController.forward();
    } else {
      _slideController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isConnected) {
      return _buildConnectedStatus();
    } else {
      return _buildDisconnectedStatus();
    }
  }

  Widget _buildConnectedStatus() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.defaultPadding,
          vertical: UIConstants.smallPadding,
        ),
        decoration: BoxDecoration(
          color: const Color(UIConstants.successColorValue),
          boxShadow: [
            BoxShadow(
              color: const Color(UIConstants.successColorValue).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(
                Icons.cloud_done,
                color: Colors.white,
                size: UIConstants.defaultIconSize,
              ),
              const SizedBox(width: UIConstants.smallPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to server',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ApiConstants.defaultBaseUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedStatus() {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.defaultPadding,
            ),
            decoration: BoxDecoration(
              color: const Color(UIConstants.errorColorValue),
              boxShadow: [
                BoxShadow(
                  color: const Color(UIConstants.errorColorValue).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(
                          Icons.cloud_off,
                          color: Colors.white,
                          size: UIConstants.defaultIconSize,
                        ),
                      ),
                      const SizedBox(width: UIConstants.smallPadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not connected to server',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Trying to connect to: ${ApiConstants.defaultBaseUrl}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 10,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check your connection and try again',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onRetry != null)
                        _buildRetryButton(),
                    ],
                  ),
                  const SizedBox(height: UIConstants.smallPadding),
                  _buildConnectionHelp(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRetryButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onRetry?.call();
          },
          borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: UIConstants.smallIconSize,
                ),
                const SizedBox(width: UIConstants.smallPadding / 2),
                Text(
                  'Retry',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionHelp() {
    return Container(
      padding: const EdgeInsets.all(UIConstants.smallPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withOpacity(0.9),
            size: UIConstants.smallIconSize,
          ),
          const SizedBox(width: UIConstants.smallPadding),
          Expanded(
            child: Text(
              'Make sure the backend server is running on localhost:8010',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}