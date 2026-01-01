import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class MediaViewerScreen extends StatefulWidget {
  final StorjImageItem item;
  final List<StorjImageItem> allItems;

  const MediaViewerScreen({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late final List<StorjImageItem> _items;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitializeFuture;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _items = widget.allItems.isNotEmpty ? widget.allItems : [widget.item];
    _currentIndex = _items.indexWhere(
      (item) => item.path == widget.item.path,
    );
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
    _setupVideoControllerIfNeeded(_currentItem);
  }

  @override
  void dispose() {
    _exitFullscreen();
    _disposeVideoController();
    _pageController.dispose();
    super.dispose();
  }

  StorjImageItem get _currentItem => _items[_currentIndex];

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitializeFuture = null;
  }

  Future<void> _setupVideoControllerIfNeeded(StorjImageItem item) async {
    _disposeVideoController();
    if (!item.isVideo) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final url = _resolveMediaUrl(item);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    _videoInitializeFuture = controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    await controller.setLooping(false);
  }

  String _resolveMediaUrl(StorjImageItem item, {bool thumbnail = false}) {
    if (thumbnail) {
      if (item.thumbnailUrl.isNotEmpty) {
        return item.thumbnailUrl;
      }
      return ApiService().getStorjMediaUrl(item.path, thumbnail: true);
    }
    if (item.url.isNotEmpty) {
      return item.url;
    }
    return ApiService().getStorjMediaUrl(item.path, thumbnail: false);
  }

  Future<void> _downloadCurrent() async {
    final url = _resolveMediaUrl(_currentItem);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Invalid download URL');
      return;
    }
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) {
      _showMessage('Failed to open download link');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    final nextState = !_isFullscreen;
    setState(() {
      _isFullscreen = nextState;
    });
    if (kIsWeb) return;
    if (nextState) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _exitFullscreen() {
    if (!_isFullscreen) return;
    _isFullscreen = false;
    if (kIsWeb) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: _isFullscreen,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(
                _currentItem.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _downloadCurrent,
                  tooltip: 'Download',
                ),
              ],
            ),
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _items.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _setupVideoControllerIfNeeded(_items[index]);
          },
          itemBuilder: (context, index) {
            final item = _items[index];
            if (item.isVideo) {
              if (index != _currentIndex) {
                return _buildInactiveVideoPlaceholder(item);
              }
              return _buildVideoPlayer(item);
            }
            return _buildImageViewer(item);
          },
        ),
      ),
    );
  }

  Widget _buildInactiveVideoPlaceholder(StorjImageItem item) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _resolveMediaUrl(item, thumbnail: true),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_filled,
            color: Colors.white70,
            size: 64,
          ),
        ),
      ],
    );
  }

  Widget _buildImageViewer(StorjImageItem item) {
    final url = _resolveMediaUrl(item);
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white70,
                size: 64,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(StorjImageItem item) {
    final controller = _videoController;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FutureBuilder(
      future: _videoInitializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.value.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Text(
                controller.value.errorDescription ?? 'Failed to play video',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, VideoPlayerValue value, child) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(controller),
                          Positioned(
                            right: 16,
                            top: 16,
                            child: IconButton(
                              icon: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: Colors.white70,
                              ),
                              onPressed: _toggleFullscreen,
                              tooltip: _isFullscreen
                                  ? 'Exit Fullscreen'
                                  : 'Fullscreen',
                            ),
                          ),
                          Positioned(
                            bottom: 32,
                            child: IconButton(
                              iconSize: 56,
                              color: Colors.white70,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.defaultPadding,
                    vertical: UIConstants.smallPadding,
                  ),
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Theme.of(context).colorScheme.primary,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: UIConstants.smallPadding),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(value.position),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
