import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';

import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../widgets/liquid_glass_container.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LibraryMediaType? _typeFilter;
  SortOption _sortOption = SortOption.dateAddedDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: const Text('Media Library'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort media',
            onSelected: (opt) => setState(() => _sortOption = opt),
            itemBuilder: (context) => SortOption.values.map((opt) {
              return PopupMenuItem(
                value: opt,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: _sortOption == opt ? colorScheme.primary : null,
                    fontWeight: _sortOption == opt
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: LiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: DownloadStateManager.instance,
            builder: (context, _) {
              final items = DownloadStateManager.instance.libraryItems;
              final filter = MediaFilter(
                searchQuery: _searchQuery,
                typeFilter: _typeFilter,
                sortOption: _sortOption,
              );
              final filteredItems = filter.apply(items);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        LiquidGlassContainer(
                          padding: EdgeInsets.zero,
                          borderRadius: AppShapes.extraLarge,
                          child: SearchBar(
                            controller: _searchController,
                            elevation: const WidgetStatePropertyAll(0),
                            backgroundColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            shadowColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            surfaceTintColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            hintText: 'Search offline media...',
                            leading: const Icon(Icons.search_rounded),
                            trailing: _searchController.text.isNotEmpty
                                ? [
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    ),
                                  ]
                                : null,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('All Media'),
                                selected: _typeFilter == null,
                                onSelected: (_) =>
                                    setState(() => _typeFilter = null),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterChip(
                                label: const Text('Videos'),
                                selected: _typeFilter == LibraryMediaType.video,
                                onSelected: (_) => setState(
                                  () => _typeFilter = LibraryMediaType.video,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterChip(
                                label: const Text('Audio Only'),
                                selected: _typeFilter == LibraryMediaType.audio,
                                onSelected: (_) => setState(
                                  () => _typeFilter = LibraryMediaType.audio,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: filteredItems.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              MediaQuery.paddingOf(context).bottom + 108,
                            ),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _MediaCard(
                                item: item,
                                onOpen: () =>
                                    _openInExternalPlayer(context, item),
                                onDetails: () => _openMediaModal(context, item),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Account for the search and filter controls above this Expanded region,
    // placing the card at the visual centre of the complete screen.
    return Transform.translate(
      offset: const Offset(0, -88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: LiquidGlassContainer(
            key: const Key('library-empty-state'),
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderRadius: AppShapes.extraLarge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.video_library_outlined,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your Library is Empty',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Downloaded videos and audio tracks will be indexed here automatically.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInExternalPlayer(
    BuildContext context,
    MediaItem item,
  ) async {
    if (item.localFilePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media file path is unavailable.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final opened = await NativeBridge.openInExternalPlayer(
      filePath: item.localFilePath,
      title: item.title,
      isVideo: item.mediaType == LibraryMediaType.video,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No external player found (such as VLC or mpv) or file is missing.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmRemove(BuildContext context, MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove from library?'),
          content: Text(
            '"${item.title}" will be removed from this list. '
            'The downloaded file stays in your device storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      DownloadStateManager.instance.deleteMediaItem(item.id);
    }
  }

  void _openMediaModal(BuildContext context, MediaItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isVideo = item.mediaType == LibraryMediaType.video;
    final details = <String>[
      if (item.durationSeconds > 0) _formatDuration(item.durationSeconds),
      if (item.fileSizeBytes > 0) _formatBytes(item.fileSizeBytes),
      if (item.videoCodec != null) item.videoCodec!.toUpperCase(),
      if (item.audioCodec != null) item.audioCodec!.toUpperCase(),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: LiquidGlassContainer(
              padding: AppSpacing.cardPadding,
              borderRadius: AppShapes.extraLarge,
              enableBlur: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppShapes.medium),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _buildThumbnail(item, iconSize: 28),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              item.resolution ?? (isVideo ? 'Video' : 'Audio'),
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                details.join(' • '),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Opens in VLC, mpv, or any other installed media player on your device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openInExternalPlayer(context, item);
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open in External Player'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _confirmRemove(context, item);
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      label: const Text('Remove from Library'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(MediaItem item, {double iconSize = 22}) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        item.mediaType == LibraryMediaType.video
            ? Icons.movie_outlined
            : Icons.audiotrack_outlined,
        size: iconSize,
        color: colorScheme.primary,
      ),
    );

    final url = item.thumbnailPath;
    final hasRemote =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return hasRemote
        ? Image.network(
            url,
            fit: BoxFit.cover,
            // Decode at display size: full-resolution thumbnails cost real
            // memory and cause decode jank while scrolling.
            cacheWidth: 240,
            errorBuilder: (_, __, ___) => fallback,
          )
        : fallback;
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _formatBytes(int bytes) {
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).round()} KB';
    return '$bytes B';
  }
}

class _MediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  const _MediaCard({
    required this.item,
    required this.onOpen,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isVideo = item.mediaType == LibraryMediaType.video;

    return LiquidGlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppShapes.large,
      onTap: onDetails,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppShapes.small),
            child: SizedBox(
              width: 78,
              height: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _LibraryThumb(item: item),
                  if (item.durationSeconds > 0)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(170),
                          borderRadius: BorderRadius.circular(
                            AppShapes.extraSmall,
                          ),
                        ),
                        child: Text(
                          _LibraryScreenState._formatDuration(
                            item.durationSeconds,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  item.resolution ?? (isVideo ? 'Video' : 'Audio'),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded),
            color: colorScheme.primary,
            iconSize: 32,
            tooltip: 'Open in external player',
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _LibraryThumb extends StatelessWidget {
  final MediaItem item;

  const _LibraryThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        item.mediaType == LibraryMediaType.video
            ? Icons.movie_outlined
            : Icons.audiotrack_outlined,
        color: colorScheme.primary,
        size: 22,
      ),
    );

    final url = item.thumbnailPath;
    final hasRemote =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    if (!hasRemote) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
