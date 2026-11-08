import '../models/media_item.dart';
import '../models/sort_option.dart';

class MediaFilter {
  final String searchQuery;
  final LibraryMediaType? typeFilter;
  final String? collectionFilter;
  final SortOption sortOption;

  const MediaFilter({
    this.searchQuery = '',
    this.typeFilter,
    this.collectionFilter,
    this.sortOption = SortOption.dateAddedDesc,
  });

  List<MediaItem> apply(List<MediaItem> items) {
    var result = items.where((item) {
      // 1. Search Query
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesCollection = item.collection?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesCollection) return false;
      }

      // 2. MediaType filter
      if (typeFilter != null && item.mediaType != typeFilter) {
        return false;
      }

      // 3. Collection filter
      if (collectionFilter != null && collectionFilter!.isNotEmpty) {
        if (item.collection != collectionFilter) return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (sortOption) {
      case SortOption.dateAddedDesc:
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case SortOption.dateAddedAsc:
        result.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case SortOption.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.titleDesc:
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SortOption.sizeDesc:
        result.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case SortOption.sizeAsc:
        result.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
        break;
      case SortOption.durationDesc:
        result.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
        break;
    }

    return result;
  }
}
