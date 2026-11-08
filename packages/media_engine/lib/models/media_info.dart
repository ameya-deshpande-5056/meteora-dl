import 'package:meta/meta.dart';
import 'format_info.dart';
import 'stream_type.dart';

@immutable
class MediaInfo {
  final String id;
  final String title;
  final String? uploader;
  final String? uploaderId;
  final int? durationSeconds;
  final String? thumbnail;
  final String? webpageUrl;
  final String? extractor;
  final String? description;
  final List<FormatInfo> formats;
  final List<String> subtitles;

  const MediaInfo({
    required this.id,
    required this.title,
    this.uploader,
    this.uploaderId,
    this.durationSeconds,
    this.thumbnail,
    this.webpageUrl,
    this.extractor,
    this.description,
    required this.formats,
    this.subtitles = const [],
  });

  List<FormatInfo> get videoOnlyFormats =>
      formats.where((f) => f.streamType == StreamType.videoOnly).toList();

  List<FormatInfo> get audioOnlyFormats =>
      formats.where((f) => f.streamType == StreamType.audioOnly).toList();

  List<FormatInfo> get combinedFormats =>
      formats.where((f) => f.streamType == StreamType.combined).toList();

  factory MediaInfo.fromJson(Map<String, dynamic> json) {
    final rawFormats = json['formats'] as List<dynamic>? ?? [];
    final parsedFormats = rawFormats
        .whereType<Map<String, dynamic>>()
        .map((f) => FormatInfo.fromJson(f))
        .toList();

    final rawSubtitles = json['subtitles'] as Map<String, dynamic>? ?? {};

    return MediaInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Media').toString(),
      uploader: json['uploader'] as String?,
      uploaderId: json['uploader_id'] as String?,
      durationSeconds: json['duration'] is num ? (json['duration'] as num).toInt() : null,
      thumbnail: json['thumbnail'] as String?,
      webpageUrl: json['webpage_url'] as String?,
      extractor: json['extractor_key'] as String? ?? json['extractor'] as String?,
      description: json['description'] as String?,
      formats: parsedFormats,
      subtitles: rawSubtitles.keys.toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'uploader': uploader,
    'uploader_id': uploaderId,
    'duration': durationSeconds,
    'thumbnail': thumbnail,
    'webpage_url': webpageUrl,
    'extractor': extractor,
    'description': description,
    'formats': formats.map((f) => f.toJson()).toList(),
    'subtitles': subtitles,
  };
}
