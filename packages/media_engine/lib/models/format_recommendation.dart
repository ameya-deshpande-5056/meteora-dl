import 'package:meta/meta.dart';
import 'format_info.dart';

@immutable
class FormatRecommendation {
  final FormatInfo? videoFormat;
  final FormatInfo? audioFormat;
  final FormatInfo? combinedFormat;
  final bool requiresMuxing;
  final bool directStreamCopyPossible;
  final int estimatedSizeBytes;
  final String reasoning;
  final double qualityScore;

  const FormatRecommendation({
    this.videoFormat,
    this.audioFormat,
    this.combinedFormat,
    required this.requiresMuxing,
    required this.directStreamCopyPossible,
    required this.estimatedSizeBytes,
    required this.reasoning,
    required this.qualityScore,
  });

  String get ytdlpFormatSelector {
    if (combinedFormat != null) {
      return combinedFormat!.formatId;
    }
    if (videoFormat != null && audioFormat != null) {
      return '${videoFormat!.formatId}+${audioFormat!.formatId}';
    }
    if (videoFormat != null) {
      return videoFormat!.formatId;
    }
    if (audioFormat != null) {
      return audioFormat!.formatId;
    }
    return 'bestvideo+bestaudio/best';
  }

  String get targetExtension {
    if (combinedFormat != null) return combinedFormat!.ext;
    if (videoFormat != null) {
      // If video is MP4/AVC and audio is M4A/AAC, container is mp4
      if (videoFormat!.ext == 'mp4' && (audioFormat?.ext == 'm4a' || audioFormat?.ext == 'mp4')) {
        return 'mp4';
      }
      // If WebM / VP9 / Opus
      if (videoFormat!.ext == 'webm' || audioFormat?.ext == 'webm' || audioFormat?.ext == 'opus') {
        return 'mkv'; // Matroska accepts any streams with direct copy
      }
      return 'mp4';
    }
    return audioFormat?.ext ?? 'mp3';
  }
}
