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
  final String? language;
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
    this.language,
    required this.streamType,
  });

  int? get estimatedSizeBytes => filesize ?? filesizeApprox;

  String get resolutionLabel {
    if (height != null) {
      final fpsSuffix = (fps != null && fps! > 30) ? 'p${fps!.round()}' : 'p';
      return '$height$fpsSuffix';
    }
    if (streamType == StreamType.audioOnly) {
      final bitrate = abr ?? tbr;
      if (bitrate != null) return '${bitrate.round()} kbps';
      return 'Audio';
    }
    return formatNote.isNotEmpty ? formatNote : 'Unknown';
  }

  String get displayVideoCodec {
    final raw = (vcodec ?? '').toLowerCase();
    if (raw.isEmpty || raw == 'none') return ext.toUpperCase();
    if (raw.contains('av01') || raw.contains('av1')) return 'AV1';
    if (raw.contains('vp09') || raw.contains('vp9')) return 'VP9';
    if (raw.contains('vp8')) return 'VP8';
    if (raw.contains('hev1') || raw.contains('hvc1') || raw.contains('hevc') || raw.contains('h265')) {
      return 'H.265';
    }
    if (raw.contains('avc1') || raw.contains('h264')) return 'H.264';
    return raw.split('.').first.toUpperCase();
  }

  String get displayAudioCodec {
    final raw = (acodec ?? '').toLowerCase();
    if (raw.isEmpty || raw == 'none') return ext.toUpperCase();
    if (raw.contains('opus')) return 'Opus';
    if (raw.contains('mp4a') || raw.contains('aac')) return 'AAC';
    if (raw.contains('mp3')) return 'MP3';
    if (raw.contains('vorbis')) return 'Vorbis';
    if (raw.contains('flac')) return 'FLAC';
    if (raw.contains('ec-3') || raw.contains('ac-3')) return 'Dolby';
    return raw.split('.').first.toUpperCase();
  }

  String get audioBitrateLabel {
    final bitrate = abr ?? (streamType == StreamType.audioOnly ? tbr : null);
    if (bitrate != null && bitrate > 0) {
      return '${bitrate.round()} kbps';
    }
    return formatNote.isNotEmpty ? formatNote : 'Audio';
  }

  String get formattedSize {
    final bytes = estimatedSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / kb).round()} KB';
  }

  String get videoSelectionLabel {
    final parts = <String>[
      resolutionLabel,
      displayVideoCodec,
      ext.toUpperCase(),
    ];
    final size = formattedSize;
    final base = parts.join(' • ');
    return size.isNotEmpty ? '$base ($size)' : base;
  }

  String get audioSelectionLabel {
    final parts = <String>[
      audioBitrateLabel,
      displayAudioCodec,
      ext.toUpperCase(),
      if (language != null && language!.isNotEmpty) language!.toUpperCase(),
    ];
    final size = formattedSize;
    final base = parts.join(' • ');
    return size.isNotEmpty ? '$base ($size)' : base;
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
      language: json['language'] as String?,
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
    'language': language,
    'stream_type': streamType.name,
  };
}
