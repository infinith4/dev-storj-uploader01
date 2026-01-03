import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'media_viewer_screen.dart';

enum GallerySortOption {
  capturedDate,
  uploadedDate,
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<StorjImageItem> _images = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  // Smaller page size to reduce initial payload and speed up first paint
  static const int _pageSize = 12;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  GallerySortOption _sortOption = GallerySortOption.capturedDate;
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  bool _isDeleting = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isShiftPressed = false;
  int? _lastSelectedIndex;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreImages();
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      final response = await ApiService().getStorjImages(
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _images = _sortImages(response.images);
          _currentOffset = response.images.length;
          _hasMore = response.images.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ApiService().getStorjImages(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          final combined = List<StorjImageItem>.from(_images)
            ..addAll(response.images);
          _images = _sortImages(combined);
          _currentOffset += response.images.length;
          _hasMore = response.images.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _openMediaViewer(StorjImageItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaViewerScreen(
          item: item,
          allItems: _images,
        ),
      ),
    );
  }

  void _setSelectionMode(bool enabled) {
    setState(() {
      _isSelectionMode = enabled;
      if (!enabled) {
        _selectedPaths.clear();
        _lastSelectedIndex = null;
      }
    });
  }

  void _toggleSelectionAtIndex(int index) {
    if (index < 0 || index >= _images.length) return;
    final item = _images[index];
    setState(() {
      if (_selectedPaths.contains(item.path)) {
        _selectedPaths.remove(item.path);
      } else {
        _selectedPaths.add(item.path);
      }
      _lastSelectedIndex = index;
    });
  }

  void _selectRange(int index) {
    if (_images.isEmpty) return;
    final anchor = _lastSelectedIndex ?? index;
    final start = math.min(anchor, index);
    final end = math.max(anchor, index);
    setState(() {
      _isSelectionMode = true;
      for (var i = start; i <= end; i++) {
        _selectedPaths.add(_images[i].path);
      }
      _lastSelectedIndex = index;
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    final isShift = event.isShiftPressed;
    if (_isShiftPressed != isShift && mounted) {
      setState(() {
        _isShiftPressed = isShift;
      });
    }
  }

  Widget _wrapWithKeyboardListener(Widget child) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: child,
    );
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedPaths.isEmpty || _isDeleting) return;

    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('削除の確認'),
          content: Text('$count 件のメディアを削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await ApiService().deleteStorjMedia(
        _selectedPaths.toList(),
      );

      final deletedSet = response.deleted.toSet();
      if (mounted) {
        setState(() {
          _images = _images.where((item) => !deletedSet.contains(item.path)).toList();
          _selectedPaths.removeWhere(deletedSet.contains);
          _currentOffset = _images.length;
          if (_selectedPaths.isEmpty) {
            _isSelectionMode = false;
          }
        });
      }

      if (mounted) {
        final failCount = response.failed.length;
        if (failCount == 0) {
          _showSnackBar('削除しました: ${deletedSet.length}件');
        } else {
          _showSnackBar(
            '削除失敗: $failCount件（成功: ${deletedSet.length}件）',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('削除に失敗しました: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(UIConstants.errorColorValue) : null,
      ),
    );
  }

  List<StorjImageItem> _sortImages(List<StorjImageItem> items) {
    final sorted = List<StorjImageItem>.from(items);
    sorted.sort((a, b) {
      final aDate = _sortOption == GallerySortOption.capturedDate
          ? _resolveCapturedDate(a)
          : _resolveUploadedDate(a);
      final bDate = _sortOption == GallerySortOption.capturedDate
          ? _resolveCapturedDate(b)
          : _resolveUploadedDate(b);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  DateTime _resolveUploadedDate(StorjImageItem item) {
    return _parseModifiedTime(item.modifiedTime) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _resolveCapturedDate(StorjImageItem item) {
    return _extractDateTime(item.filename) ??
        _extractDateTime(item.path) ??
        _parseModifiedTime(item.modifiedTime) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parseModifiedTime(String value) {
    if (value.isEmpty) return null;
    final normalized = value.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  DateTime? _extractDateTime(String value) {
    final dateTimeMatch = RegExp(
      r'(20\d{2})(\d{2})(\d{2})[T_\-]?(\d{2})(\d{2})(\d{2})',
    ).firstMatch(value);
    if (dateTimeMatch != null) {
      return DateTime(
        int.parse(dateTimeMatch.group(1)!),
        int.parse(dateTimeMatch.group(2)!),
        int.parse(dateTimeMatch.group(3)!),
        int.parse(dateTimeMatch.group(4)!),
        int.parse(dateTimeMatch.group(5)!),
        int.parse(dateTimeMatch.group(6)!),
      );
    }

    final dateMatch = RegExp(r'(20\d{2})(\d{2})(\d{2})').firstMatch(value);
    if (dateMatch != null) {
      return DateTime(
        int.parse(dateMatch.group(1)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(3)!),
      );
    }

    return null;
  }

  String _sortOptionLabel(GallerySortOption option) {
    switch (option) {
      case GallerySortOption.capturedDate:
        return '撮影日時';
      case GallerySortOption.uploadedDate:
        return 'アップロード日';
    }
  }

  Widget _buildDefaultThumbnail(StorjImageItem item, {bool isLoading = false}) {
    final icon = item.isVideo ? Icons.videocam : Icons.image_outlined;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No thumbnail',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final videoCount = _images.where((item) => item.isVideo).length;
    final imageCount = _images.length - videoCount;

    return Padding(
      padding: const EdgeInsets.all(UIConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: UIConstants.smallPadding,
            runSpacing: UIConstants.smallPadding,
            children: [
              Text(
                '$imageCount images • $videoCount videos • ${_images.length} total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _isSelectionMode ? '選択中: ${_selectedPaths.length}' : 'ソート',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: UIConstants.smallPadding),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: UIConstants.smallPadding,
              runSpacing: UIConstants.smallPadding,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_isSelectionMode)
                  PopupMenuButton<GallerySortOption>(
                    tooltip: 'ソート',
                    initialValue: _sortOption,
                    onSelected: (value) {
                      setState(() {
                        _sortOption = value;
                        _images = _sortImages(_images);
                      });
                    },
                    itemBuilder: (context) {
                      return GallerySortOption.values.map((option) {
                        return CheckedPopupMenuItem<GallerySortOption>(
                          value: option,
                          checked: option == _sortOption,
                          child: Text(_sortOptionLabel(option)),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortOptionLabel(_sortOption),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.expand_more,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isSelectionMode) ...[
                  TextButton(
                    onPressed: _isDeleting ? null : () => _setSelectionMode(false),
                    child: const Text('キャンセル'),
                  ),
                  IconButton(
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    onPressed: (!_isDeleting && _selectedPaths.isNotEmpty)
                        ? _confirmDeleteSelected
                        : null,
                    tooltip: 'Delete',
                    iconSize: 20,
                  ),
                ] else ...[
                  TextButton(
                    onPressed: (_isDeleting || _images.isEmpty)
                        ? null
                        : () => _setSelectionMode(true),
                    child: const Text('選択'),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isDeleting ? null : _loadImages,
                  tooltip: 'Refresh',
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _wrapWithKeyboardListener(const Center(
        child: CircularProgressIndicator(),
      ));
    }

    if (_errorMessage != null) {
      return _wrapWithKeyboardListener(Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(UIConstants.defaultPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: UIConstants.defaultPadding),
                    Text(
                      'Failed to load gallery',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: UIConstants.smallPadding),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: UIConstants.defaultPadding),
                    ElevatedButton.icon(
                      onPressed: _loadImages,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ));
    }

    if (_images.isEmpty) {
      return _wrapWithKeyboardListener(Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: UIConstants.defaultPadding),
                  Text(
                    'No images or videos found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: UIConstants.smallPadding),
                  Text(
                    'Upload files to see them here',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: UIConstants.defaultPadding),
                  ElevatedButton.icon(
                    onPressed: _loadImages,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));
    }

    return _wrapWithKeyboardListener(RefreshIndicator(
      onRefresh: _loadImages,
      child: Column(
        children: [
          // Header with count
          _buildHeader(),
          // Grid
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(UIConstants.smallPadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _images.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _images.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final item = _images[index];
                return _buildGridItem(item, index);
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildGridItem(StorjImageItem item, int index) {
    final thumbnailUrl = item.thumbnailUrl.isNotEmpty
        ? item.thumbnailUrl
        : ApiService().getStorjMediaUrl(item.path, thumbnail: true);
    final isSelected = _selectedPaths.contains(item.path);
    return GestureDetector(
      onTap: () {
        _keyboardFocusNode.requestFocus();
        if (_isSelectionMode || _isShiftPressed) {
          if (!_isSelectionMode) {
            _setSelectionMode(true);
          }
          if (_isShiftPressed) {
            _selectRange(index);
          } else {
            _toggleSelectionAtIndex(index);
          }
        } else {
          _openMediaViewer(item);
        }
      },
      onLongPress: () {
        _keyboardFocusNode.requestFocus();
        if (!_isSelectionMode) {
          _setSelectionMode(true);
        }
        _toggleSelectionAtIndex(index);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            // Reduce decode/cache size to speed up loading and cut bandwidth
            memCacheWidth: 512,
            memCacheHeight: 512,
            maxWidthDiskCache: 512,
            maxHeightDiskCache: 512,
            placeholder: (context, url) => _buildDefaultThumbnail(
              item,
              isLoading: true,
            ),
            errorWidget: (context, url, error) => _buildDefaultThumbnail(item),
          ),
          if (_isSelectionMode && isSelected)
            Container(
              color: Colors.black.withOpacity(0.25),
            ),
          if (_isSelectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.circle_outlined,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),

          // Video badge
          if (item.isVideo)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // File size badge
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.formattedSize,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
