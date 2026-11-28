import 'package:meta/meta.dart';

@immutable
class PlaylistEntry {
  final String id;
  final String title;
  final String url;
  final String? uploader;
  final int? durationSeconds;
  final String? thumbnail;

  const PlaylistEntry({
    required this.id,
    required this.title,
    required this.url,
    this.uploader,
    this.durationSeconds,
    this.thumbnail,
  });

  static String? _parseThumbnail(Map<String, dynamic> json) {
    final direct = json['thumbnail'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    if (json['thumbnails'] is List) {
      final thumbs = (json['thumbnails'] as List).whereType<Map<String, dynamic>>().toList();
      if (thumbs.isNotEmpty) {
        return thumbs.last['url'] as String?;
      }
    }
    return null;
  }

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final url = json['url'] != null && json['url'].toString().startsWith('http')
        ? json['url'].toString()
        : 'https://www.youtube.com/watch?v=$id';

    return PlaylistEntry(
      id: id,
      title: (json['title'] ?? 'Untitled Item').toString(),
      url: url,
      uploader: json['uploader'] as String? ?? json['channel'] as String?,
      durationSeconds: json['duration'] is num ? (json['duration'] as num).toInt() : null,
      thumbnail: _parseThumbnail(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'uploader': uploader,
    'duration': durationSeconds,
    'thumbnail': thumbnail,
  };
}

@immutable
class PlaylistInfo {
  final String id;
  final String title;
  final String? uploader;
  final String? description;
  final String? thumbnail;
  final int itemCount;
  final List<PlaylistEntry> entries;

  const PlaylistInfo({
    required this.id,
    required this.title,
    this.uploader,
    this.description,
    this.thumbnail,
    required this.itemCount,
    required this.entries,
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final parsedEntries = rawEntries
        .whereType<Map<String, dynamic>>()
        .map((e) => PlaylistEntry.fromJson(e))
        .toList();

    var thumbnail = PlaylistEntry._parseThumbnail(json);
    if (thumbnail == null || thumbnail.isEmpty) {
      for (final entry in parsedEntries) {
        if (entry.thumbnail != null && entry.thumbnail!.isNotEmpty) {
          thumbnail = entry.thumbnail;
          break;
        }
      }
    }

    return PlaylistInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Playlist').toString(),
      uploader: json['uploader'] as String? ?? json['channel'] as String?,
      description: json['description'] as String?,
      thumbnail: thumbnail,
      itemCount: parsedEntries.length,
      entries: parsedEntries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'uploader': uploader,
    'description': description,
    'thumbnail': thumbnail,
    'item_count': itemCount,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}
