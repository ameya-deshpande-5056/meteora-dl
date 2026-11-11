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
                    fontWeight: _sortOption == opt ? FontWeight.w600 : FontWeight.normal,
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
                  // Liquid Glass Search Bar & Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                    child: Column(
                      children: [
                        LiquidGlassContainer(
                          padding: EdgeInsets.zero,
                          borderRadius: AppShapes.extraLarge,
                          child: SearchBar(
                            controller: _searchController,
                            elevation: const WidgetStatePropertyAll(0),
                            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
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
                                    )
                                  ]
                                : null,
                            onChanged: (val) => setState(() => _searchQuery = val),
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
                                onSelected: (_) => setState(() => _typeFilter = null),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterChip(
                                label: const Text('Videos'),
                                selected: _typeFilter == LibraryMediaType.video,
                                onSelected: (_) => setState(() => _typeFilter = LibraryMediaType.video),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterChip(
                                label: const Text('Audio Only'),
                                selected: _typeFilter == LibraryMediaType.audio,
                                onSelected: (_) => setState(() => _typeFilter = LibraryMediaType.audio),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Media Items
                  Expanded(
                    child: filteredItems.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              MediaQuery.paddingOf(context).bottom + 96,
                            ),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return Card(
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppShapes.small),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        item.mediaType == LibraryMediaType.video
                                            ? Icons.movie_outlined
                                            : Icons.audiotrack_outlined,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${item.resolution ?? (item.mediaType == LibraryMediaType.audio ? "Audio" : "Video")} • ${item.localFilePath.isNotEmpty ? "Ready to play" : "Pending path"}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_fill_rounded),
                                    color: colorScheme.primary,
                                    iconSize: 32,
                                    tooltip: 'Open in external player',
                                    onPressed: () => _openInExternalPlayer(context, item),
                                  ),
                                  onTap: () => _openMediaModal(context, item),
                                ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Your Library is Empty',
              style: theme.textTheme.titleMedium,
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
    );
  }

  Future<void> _openInExternalPlayer(BuildContext context, MediaItem item) async {
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
          content: Text('No external player found (such as VLC or mpv) or file is missing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openMediaModal(BuildContext context, MediaItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isVideo = item.mediaType == LibraryMediaType.video;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppShapes.medium),
                      ),
                      child: Icon(
                        isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                        color: colorScheme.onPrimaryContainer,
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
                            '${item.resolution ?? (isVideo ? "Video" : "Audio")}${item.videoCodec != null ? " • ${item.videoCodec}" : ""}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Opens in VLC, mpv, or any other installed media player on your device.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
                      DownloadStateManager.instance.deleteMediaItem(item.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete from Library'),
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
}
