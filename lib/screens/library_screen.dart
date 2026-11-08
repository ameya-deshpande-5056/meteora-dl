import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import '../state/download_state.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/glass_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _searchQuery = '';
  LibraryMediaType? _typeFilter;
  SortOption _sortOption = SortOption.dateAddedDesc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Library'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded, color: LiquidGlassTheme.cyanAccent),
            onSelected: (opt) => setState(() => _sortOption = opt),
            itemBuilder: (context) => SortOption.values.map((opt) {
              return PopupMenuItem(
                value: opt,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: _sortOption == opt ? LiquidGlassTheme.cyanAccent : LiquidGlassTheme.textPrimary,
                    fontWeight: _sortOption == opt ? FontWeight.bold : FontWeight.normal,
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
            children: [
              // Search & Filter Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: LiquidGlassTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search offline media...',
                        hintStyle: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: LiquidGlassTheme.textSecondary, size: 20),
                        filled: true,
                        fillColor: LiquidGlassTheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: LiquidGlassTheme.glassBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'All Media',
                          isSelected: _typeFilter == null,
                          onTap: () => setState(() => _typeFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Videos',
                          isSelected: _typeFilter == LibraryMediaType.video,
                          onTap: () => setState(() => _typeFilter = LibraryMediaType.video),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Audio Only',
                          isSelected: _typeFilter == LibraryMediaType.audio,
                          onTap: () => setState(() => _typeFilter = LibraryMediaType.audio),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Media Items
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined, size: 64, color: LiquidGlassTheme.textMuted.withAlpha(100)),
                            const SizedBox(height: 16),
                            const Text(
                              'Library is empty',
                              style: TextStyle(color: LiquidGlassTheme.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Downloaded media will appear here automatically',
                              style: TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _MediaLibraryCard(
                            item: item,
                            onPlay: () => _openMediaModal(context, item),
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

  void _openMediaModal(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: LiquidGlassTheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Media Player simulation
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, color: LiquidGlassTheme.cyanAccent, size: 54),
                      const SizedBox(height: 8),
                      Text(
                        'Android Media3 / ExoPlayer',
                        style: TextStyle(color: LiquidGlassTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: const TextStyle(
                  color: LiquidGlassTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.resolution ?? "HD"} • ${item.videoCodec ?? "AV1"} • Offline Playback',
                style: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? LiquidGlassTheme.cyanAccent.withAlpha(40) : LiquidGlassTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? LiquidGlassTheme.cyanAccent.withAlpha(100) : LiquidGlassTheme.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? LiquidGlassTheme.cyanAccent : LiquidGlassTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MediaLibraryCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onPlay;

  const _MediaLibraryCard({required this.item, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final isVideo = item.mediaType == LibraryMediaType.video;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: onPlay,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: LiquidGlassTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVideo ? Icons.movie_outlined : Icons.audiotrack_rounded,
              color: isVideo ? LiquidGlassTheme.cyanAccent : LiquidGlassTheme.indigoAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: LiquidGlassTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.resolution ?? "HD"} • Saved to MediaStore',
                  style: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_filled_rounded, color: LiquidGlassTheme.cyanAccent, size: 28),
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}
