import 'package:meta/meta.dart';
import 'stream_type.dart';

@immutable
class FormatInfo {
  final String formatId;
  final String formatNote;
  final String ext;
  final int? width;
  final int? height;
  final double? fps;
  final String? vcodec;
  final String? acodec;
  final int? filesize;
  final int? filesizeApprox;
  final double? tbr; // total bitrate in kbps
  final double? vbr; // video bitrate in kbps
  final double? abr; // audio bitrate in kbps
  final int? asr; // audio sampling rate in Hz
  final StreamType streamType;

  const FormatInfo({
    required this.formatId,
    required this.formatNote,
    required this.ext,
    this.width,
    this.height,
    this.fps,
    this.vcodec,
    this.acodec,
    this.filesize,
    this.filesizeApprox,
    this.tbr,
    this.vbr,
    this.abr,
    this.asr,
    required this.streamType,
  });

  int? get estimatedSizeBytes => filesize ?? filesizeApprox;

  String get resolutionLabel {
    if (height != null) {
      final fpsSuffix = (fps != null && fps! > 30) ? 'p${fps!.round()}' : 'p';
      return '${height}$fpsSuffix';
    }
    if (streamType == StreamType.audioOnly) {
      if (abr != null) return '${abr!.round()} kbps';
      return 'Audio';
    }
    return formatNote.isNotEmpty ? formatNote : 'Unknown';
  }

  factory FormatInfo.fromJson(Map<String, dynamic> json) {
    final vcodec = json['vcodec'] as String?;
    final acodec = json['acodec'] as String?;
    final hasVideo = vcodec != null && vcodec != 'none';
    final hasAudio = acodec != null && acodec != 'none';

    final StreamType type;
    if (hasVideo && hasAudio) {
      type = StreamType.combined;
    } else if (hasVideo) {
      type = StreamType.videoOnly;
    } else {
      type = StreamType.audioOnly;
    }

    return FormatInfo(
      formatId: (json['format_id'] ?? '').toString(),
      formatNote: (json['format_note'] ?? '').toString(),
      ext: (json['ext'] ?? 'mp4').toString(),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      fps: json['fps'] is num ? (json['fps'] as num).toDouble() : null,
      vcodec: vcodec,
      acodec: acodec,
      filesize: json['filesize'] is num ? (json['filesize'] as num).toInt() : null,
      filesizeApprox: json['filesize_approx'] is num ? (json['filesize_approx'] as num).toInt() : null,
      tbr: json['tbr'] is num ? (json['tbr'] as num).toDouble() : null,
      vbr: json['vbr'] is num ? (json['vbr'] as num).toDouble() : null,
      abr: json['abr'] is num ? (json['abr'] as num).toDouble() : null,
      asr: json['asr'] is num ? (json['asr'] as num).toInt() : null,
      streamType: type,
    );
  }

  Map<String, dynamic> toJson() => {
    'format_id': formatId,
    'format_note': formatNote,
    'ext': ext,
    'width': width,
    'height': height,
    'fps': fps,
    'vcodec': vcodec,
    'acodec': acodec,
    'filesize': filesize,
    'filesize_approx': filesizeApprox,
    'tbr': tbr,
    'vbr': vbr,
    'abr': abr,
    'asr': asr,
    'stream_type': streamType.name,
  };
}
