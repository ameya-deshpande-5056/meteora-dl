import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';

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
      appBar: AppBar(
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
      body: ListenableBuilder(
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
              // Search Bar & Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    SearchBar(
                      controller: _searchController,
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
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
                        padding: AppSpacing.screenPadding,
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
                                '${item.resolution ?? "HD"} • Saved to MediaStore',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded),
                                color: colorScheme.primary,
                                iconSize: 32,
                                onPressed: () => _openMediaModal(context, item),
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

  void _openMediaModal(BuildContext context, MediaItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: AppShapes.bottomSheetShape,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player Screen Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppShapes.medium),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 56, color: colorScheme.primary),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Android Media3 / ExoPlayer Engine',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${item.resolution ?? "HD"} • ${item.videoCodec ?? "AV1"} • Local MediaStore',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}
