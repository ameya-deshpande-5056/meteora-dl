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

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final url = json['url'] != null && json['url'].toString().startsWith('http')
        ? json['url'].toString()
        : 'https://www.youtube.com/watch?v=$id';

    return PlaylistEntry(
      id: id,
      title: (json['title'] ?? 'Untitled Item').toString(),
      url: url,
      uploader: json['uploader'] as String?,
      durationSeconds: json['duration'] is num ? (json['duration'] as num).toInt() : null,
      thumbnail: json['thumbnail'] as String?,
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
  final int itemCount;
  final List<PlaylistEntry> entries;

  const PlaylistInfo({
    required this.id,
    required this.title,
    this.uploader,
    this.description,
    required this.itemCount,
    required this.entries,
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final parsedEntries = rawEntries
        .whereType<Map<String, dynamic>>()
        .map((e) => PlaylistEntry.fromJson(e))
        .toList();

    return PlaylistInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Playlist').toString(),
      uploader: json['uploader'] as String?,
      description: json['description'] as String?,
      itemCount: parsedEntries.length,
      entries: parsedEntries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'uploader': uploader,
    'description': description,
    'item_count': itemCount,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}
