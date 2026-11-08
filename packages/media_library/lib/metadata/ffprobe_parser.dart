import '../models/media_item.dart';

class FFprobeParser {
  /// Parses JSON output from `ffprobe -v quiet -print_format json -show_format -show_streams <path>`
  static Map<String, dynamic> parseProbeOutput(Map<String, dynamic> ffprobeJson) {
    final format = ffprobeJson['format'] as Map<String, dynamic>? ?? {};
    final streams = ffprobeJson['streams'] as List<dynamic>? ?? [];

    String? videoCodec;
    String? audioCodec;
    String? resolution;
    int? bitRate = int.tryParse(format['bit_rate']?.toString() ?? '');
    double duration = double.tryParse(format['duration']?.toString() ?? '') ?? 0.0;
    int sizeBytes = int.tryParse(format['size']?.toString() ?? '') ?? 0;

    bool hasVideo = false;
    bool hasAudio = false;

    for (final s in streams) {
      if (s is! Map<String, dynamic>) continue;
      final codecType = s['codec_type'] as String?;
      final codecName = s['codec_name'] as String?;

      if (codecType == 'video' && !hasVideo) {
        hasVideo = true;
        videoCodec = codecName;
        final width = s['width'];
        final height = s['height'];
        if (width != null && height != null) {
          resolution = '${width}x$height';
        }
      } else if (codecType == 'audio' && !hasAudio) {
        hasAudio = true;
        audioCodec = codecName;
      }
    }

    final mediaType = hasVideo ? LibraryMediaType.video : LibraryMediaType.audio;

    return {
      'media_type': mediaType,
      'video_codec': videoCodec,
      'audio_codec': audioCodec,
      'resolution': resolution,
      'duration_seconds': duration.round(),
      'file_size_bytes': sizeBytes,
      'bit_rate': bitRate,
    };
  }
}
