import 'package:meta/meta.dart';

enum LibraryMediaType {
  video,
  audio,
}

@immutable
class MediaItem {
  final String id;
  final String title;
  final String localFilePath;
  final String? thumbnailPath;
  final LibraryMediaType mediaType;
  final int durationSeconds;
  final int fileSizeBytes;
  final String? resolution; // e.g. 1920x1080
  final String? videoCodec;  // e.g. h264, vp9, av1
  final String? audioCodec;  // e.g. aac, opus, mp3
  final int? bitRate;
  final String? collection;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final int playCount;
  final double playbackPositionSeconds;

  const MediaItem({
    required this.id,
    required this.title,
    required this.localFilePath,
    this.thumbnailPath,
    required this.mediaType,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.resolution,
    this.videoCodec,
    this.audioCodec,
    this.bitRate,
    this.collection,
    required this.addedAt,
    this.lastPlayedAt,
    this.playCount = 0,
    this.playbackPositionSeconds = 0.0,
  });

  MediaItem copyWith({
    String? title,
    String? localFilePath,
    String? thumbnailPath,
    String? collection,
    DateTime? lastPlayedAt,
    int? playCount,
    double? playbackPositionSeconds,
  }) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mediaType: mediaType,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      resolution: resolution,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      bitRate: bitRate,
      collection: collection ?? this.collection,
      addedAt: addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      playbackPositionSeconds: playbackPositionSeconds ?? this.playbackPositionSeconds,
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      localFilePath: json['local_file_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      mediaType: json['media_type'] == 'audio' ? LibraryMediaType.audio : LibraryMediaType.video,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      resolution: json['resolution'] as String?,
      videoCodec: json['video_codec'] as String?,
      audioCodec: json['audio_codec'] as String?,
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      collection: json['collection'] as String?,
      addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ?? DateTime.now(),
      lastPlayedAt: json['last_played_at'] != null ? DateTime.tryParse(json['last_played_at'] as String) : null,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      playbackPositionSeconds: (json['playback_position_seconds'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'local_file_path': localFilePath,
    'thumbnail_path': thumbnailPath,
    'media_type': mediaType.name,
    'duration_seconds': durationSeconds,
    'file_size_bytes': fileSizeBytes,
    'resolution': resolution,
    'video_codec': videoCodec,
    'audio_codec': audioCodec,
    'bit_rate': bitRate,
    'collection': collection,
    'added_at': addedAt.toIso8601String(),
    'last_played_at': lastPlayedAt?.toIso8601String(),
    'play_count': playCount,
    'playback_position_seconds': playbackPositionSeconds,
  };
}
