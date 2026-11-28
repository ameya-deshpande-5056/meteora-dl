import 'format_info.dart';
import 'media_info.dart';
import 'stream_type.dart';

/// Simplified user-facing download modes.
enum DownloadMode {
  videoAudioSubtitles(
    'Video + Audio',
    'Video stream with audio and optional subtitles',
  ),
  videoOnly(
    'Video Only',
    'Video stream without audio',
  ),
  audioOnly(
    'Audio Only',
    'Extracted audio track only',
  ),
  subtitlesOnly(
    'Subtitles Only',
    'Download subtitle tracks only',
  );

  final String label;
  final String description;

  const DownloadMode(this.label, this.description);
}

/// Maximum video height cap for playlist / batch downloads.
enum BatchQualityCap {
  best('Best', null),
  p2160('4K', 2160),
  p1440('1440p', 1440),
  p1080('1080p', 1080),
  p720('720p', 720),
  p480('480p', 480),
  p360('360p', 360);

  final String label;
  final int? maxHeight;

  const BatchQualityCap(this.label, this.maxHeight);
}

/// Preferred video container/stream format for playlist / batch downloads.
enum BatchVideoFormat {
  auto('Auto', null),
  mp4('MP4', 'mp4'),
  webm('WebM', 'webm');

  final String label;
  final String? ext;

  const BatchVideoFormat(this.label, this.ext);
}

/// Preferred audio stream/output format for playlist / batch downloads.
enum BatchAudioFormat {
  auto('Auto', null, null),
  m4a('M4A', 'm4a', 'm4a'),
  opus('Opus', 'webm', 'opus'),
  mp3('MP3', null, 'mp3');

  final String label;
  final String? streamExt;
  final String? audioConvertFormat;

  const BatchAudioFormat(this.label, this.streamExt, this.audioConvertFormat);
}

/// Maximum audio bitrate cap for playlist / batch downloads.
enum BatchAudioBitrateCap {
  best('Best', null),
  kbps320('320 kbps', 320),
  kbps256('256 kbps', 256),
  kbps192('192 kbps', 192),
  kbps128('128 kbps', 128),
  kbps96('96 kbps', 96);

  final String label;
  final int? maxAbr;

  const BatchAudioBitrateCap(this.label, this.maxAbr);
}

/// Builds safe, structured yt-dlp argument lists for [DownloadMode] and
/// user-chosen video resolution/codec, audio bitrate/codec, and subtitles.
class SimpleDownloadCommandBuilder {
  const SimpleDownloadCommandBuilder._();

  /// Returns a concise, descriptive label for the download queue and library.
  static String formatLabelFor(
    DownloadMode mode, {
    MediaInfo? media,
    FormatInfo? selectedVideo,
    FormatInfo? selectedAudio,
    List<SubtitleTrackInfo> selectedSubtitles = const [],
    BatchQualityCap qualityCap = BatchQualityCap.best,
    BatchVideoFormat videoFormat = BatchVideoFormat.auto,
    BatchAudioFormat audioFormat = BatchAudioFormat.auto,
    BatchAudioBitrateCap audioBitrate = BatchAudioBitrateCap.best,
  }) {
    switch (mode) {
      case DownloadMode.videoAudioSubtitles:
        final parts = <String>[];
        if (selectedVideo != null) {
          parts.add('${selectedVideo.resolutionLabel} ${selectedVideo.displayVideoCodec}');
        } else {
          if (qualityCap.maxHeight != null) parts.add('≤${qualityCap.label}');
          if (videoFormat != BatchVideoFormat.auto) parts.add(videoFormat.label);
        }
        if (selectedAudio != null) {
          parts.add('${selectedAudio.audioBitrateLabel} ${selectedAudio.displayAudioCodec}');
        } else {
          if (audioBitrate.maxAbr != null) parts.add('≤${audioBitrate.label}');
          if (audioFormat != BatchAudioFormat.auto && audioFormat != BatchAudioFormat.mp3) {
            parts.add(audioFormat.label);
          }
        }
        if (selectedSubtitles.isNotEmpty) {
          parts.add('${selectedSubtitles.length} sub');
        }
        if (parts.isEmpty) {
          final hasSubs = media?.hasCreatorSubtitles ?? false;
          return hasSubs ? 'Video + Audio + Subtitles' : 'Video + Audio';
        }
        return 'Video + Audio (${parts.join(' • ')})';

      case DownloadMode.videoOnly:
        if (selectedVideo != null) {
          return 'Video Only (${selectedVideo.resolutionLabel} ${selectedVideo.displayVideoCodec})';
        }
        final parts = <String>[
          if (qualityCap.maxHeight != null) '≤${qualityCap.label}',
          if (videoFormat != BatchVideoFormat.auto) videoFormat.label,
        ];
        return parts.isEmpty ? 'Video Only' : 'Video Only (${parts.join(' • ')})';

      case DownloadMode.audioOnly:
        if (selectedAudio != null) {
          return 'Audio Only (${selectedAudio.audioBitrateLabel} ${selectedAudio.displayAudioCodec})';
        }
        final parts = <String>[
          if (audioBitrate.maxAbr != null) '≤${audioBitrate.label}',
          if (audioFormat != BatchAudioFormat.auto) audioFormat.label,
        ];
        return parts.isEmpty ? 'Audio Only' : 'Audio Only (${parts.join(' • ')})';

      case DownloadMode.subtitlesOnly:
        if (selectedSubtitles.isNotEmpty) {
          final langs = selectedSubtitles.map((t) => t.code).take(3).join(', ');
          return 'Subtitles Only ($langs)';
        }
        return 'Subtitles Only';
    }
  }

  /// Builds the argument list passed to the native yt-dlp runner.
  static List<String> buildCommand({
    required String url,
    required DownloadMode mode,
    MediaInfo? media,
    FormatInfo? selectedVideo,
    FormatInfo? selectedAudio,
    List<SubtitleTrackInfo> selectedSubtitles = const [],
    BatchQualityCap qualityCap = BatchQualityCap.best,
    BatchVideoFormat videoFormat = BatchVideoFormat.auto,
    BatchAudioFormat audioFormat = BatchAudioFormat.auto,
    BatchAudioBitrateCap audioBitrate = BatchAudioBitrateCap.best,
  }) {
    final trimmedUrl = url.trim();
    final args = <String>[
      'yt-dlp',
      '--no-warnings',
    ];

    switch (mode) {
      case DownloadMode.videoAudioSubtitles:
        final String formatSelector;
        if (selectedVideo != null && selectedVideo.streamType == StreamType.combined) {
          formatSelector = selectedVideo.formatId;
        } else if (selectedVideo != null && selectedAudio != null) {
          formatSelector = '${selectedVideo.formatId}+${selectedAudio.formatId}';
        } else if (selectedVideo != null) {
          formatSelector = '${selectedVideo.formatId}+bestaudio/best';
        } else if (selectedAudio != null) {
          formatSelector = 'bestvideo+${selectedAudio.formatId}/best';
        } else {
          formatSelector = _buildBatchVideoAudioSelector(
            qualityCap: qualityCap,
            videoFormat: videoFormat,
            audioFormat: audioFormat,
            audioBitrate: audioBitrate,
          );
        }
        args.addAll(['-f', formatSelector]);

        if (selectedSubtitles.isNotEmpty) {
          _appendSubtitleFlags(args, selectedSubtitles, embed: true);
        } else if (media == null) {
          args.addAll([
            '--write-subs',
            '--embed-subs',
            '--sub-langs',
            'all,-live_chat',
            '--sub-format',
            'vtt/srt/best',
            '--sleep-subtitles',
            '2',
          ]);
        }
        break;

      case DownloadMode.videoOnly:
        final hasSplitVideo = media != null && media.videoOnlyFormats.isNotEmpty;
        final formatSelector = selectedVideo?.formatId ??
            (hasSplitVideo
                ? 'bestvideo'
                : _buildBatchVideoOnlySelector(
                    qualityCap: qualityCap,
                    videoFormat: videoFormat,
                  ));
        args.addAll(['-f', formatSelector]);

        if (selectedSubtitles.isNotEmpty) {
          _appendSubtitleFlags(args, selectedSubtitles, embed: true);
        }
        break;

      case DownloadMode.audioOnly:
        final formatSelector = selectedAudio?.formatId ??
            _buildBatchAudioOnlySelector(
              audioFormat: audioFormat,
              audioBitrate: audioBitrate,
            );
        args.addAll(['-f', formatSelector, '-x']);
        if (selectedAudio == null && audioFormat.audioConvertFormat != null) {
          args.addAll(['--audio-format', audioFormat.audioConvertFormat!]);
          if (audioFormat == BatchAudioFormat.mp3 && audioBitrate.maxAbr != null) {
            args.addAll(['--audio-quality', '${audioBitrate.maxAbr}K']);
          }
        }
        break;

      case DownloadMode.subtitlesOnly:
        args.add('--skip-download');
        if (selectedSubtitles.isNotEmpty) {
          _appendSubtitleFlags(args, selectedSubtitles, embed: false);
        } else {
          final useAutoCaptions =
              media != null && !media.hasCreatorSubtitles && media.automaticCaptions.isNotEmpty;
          if (useAutoCaptions) {
            final preferredLang = media.automaticCaptions.contains('en')
                ? 'en'
                : media.automaticCaptions.first;
            args.addAll([
              '--write-auto-subs',
              '--sub-langs',
              preferredLang,
            ]);
          } else {
            args.addAll([
              '--write-subs',
              '--sub-langs',
              'all,-live_chat',
            ]);
          }
          args.addAll([
            '--sub-format',
            'srt/vtt/best',
            '--sleep-subtitles',
            '2',
          ]);
        }
        break;
    }

    args.add(trimmedUrl);
    return args;
  }

  static void _appendSubtitleFlags(
    List<String> args,
    List<SubtitleTrackInfo> tracks, {
    required bool embed,
  }) {
    final hasCreator = tracks.any((t) => !t.isAutoGenerated);
    final hasAuto = tracks.any((t) => t.isAutoGenerated);
    if (hasCreator) {
      args.add('--write-subs');
    }
    if (hasAuto) {
      args.add('--write-auto-subs');
    }
    if (embed) {
      args.add('--embed-subs');
    }
    args.addAll([
      '--sub-langs',
      tracks.map((t) => t.code).toSet().join(','),
      '--sub-format',
      embed ? 'vtt/srt/best' : 'srt/vtt/best',
      '--sleep-subtitles',
      '2',
    ]);
  }

  static String _buildBatchVideoAudioSelector({
    required BatchQualityCap qualityCap,
    required BatchVideoFormat videoFormat,
    required BatchAudioFormat audioFormat,
    required BatchAudioBitrateCap audioBitrate,
  }) {
    final h = qualityCap.maxHeight != null ? '[height<=${qualityCap.maxHeight}]' : '';
    final vExt = videoFormat.ext != null ? '[ext=${videoFormat.ext}]' : '';
    final aExt = audioFormat.streamExt != null ? '[ext=${audioFormat.streamExt}]' : '';
    final aAbr = audioBitrate.maxAbr != null ? '[abr<=${audioBitrate.maxAbr}]' : '';
    final aFilter = '$aExt$aAbr';

    final selectors = <String>{
      if (vExt.isNotEmpty || aFilter.isNotEmpty) 'bestvideo$h$vExt+bestaudio$aFilter',
      if (aAbr.isNotEmpty) 'bestvideo$h+bestaudio$aAbr',
      if (h.isNotEmpty || vExt.isNotEmpty || aFilter.isNotEmpty) 'bestvideo$h+bestaudio',
      if (h.isNotEmpty) 'best$h',
      'bestvideo+bestaudio',
      'best',
    };
    return selectors.join('/');
  }

  static String _buildBatchAudioOnlySelector({
    required BatchAudioFormat audioFormat,
    required BatchAudioBitrateCap audioBitrate,
  }) {
    final aExt = audioFormat.streamExt != null ? '[ext=${audioFormat.streamExt}]' : '';
    final aAbr = audioBitrate.maxAbr != null ? '[abr<=${audioBitrate.maxAbr}]' : '';

    final selectors = <String>{
      if (aExt.isNotEmpty && aAbr.isNotEmpty) 'bestaudio$aExt$aAbr',
      if (aExt.isNotEmpty) 'bestaudio$aExt',
      if (aAbr.isNotEmpty) 'bestaudio$aAbr',
      'bestaudio',
      'best',
    };
    return selectors.join('/');
  }

  static String _buildBatchVideoOnlySelector({
    required BatchQualityCap qualityCap,
    required BatchVideoFormat videoFormat,
  }) {
    final h = qualityCap.maxHeight != null ? '[height<=${qualityCap.maxHeight}]' : '';
    final vExt = videoFormat.ext != null ? '[ext=${videoFormat.ext}]' : '';

    final selectors = <String>{
      if (vExt.isNotEmpty) 'bestvideo$h$vExt',
      if (h.isNotEmpty) 'bestvideo$h',
      if (h.isNotEmpty) 'best$h',
      'bestvideo',
      'best',
    };
    return selectors.join('/');
  }
}
