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
  }) {
    switch (mode) {
      case DownloadMode.videoAudioSubtitles:
        final parts = <String>[];
        if (selectedVideo != null) {
          parts.add('${selectedVideo.resolutionLabel} ${selectedVideo.displayVideoCodec}');
        }
        if (selectedAudio != null) {
          parts.add('${selectedAudio.audioBitrateLabel} ${selectedAudio.displayAudioCodec}');
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
        return 'Video Only';

      case DownloadMode.audioOnly:
        if (selectedAudio != null) {
          return 'Audio Only (${selectedAudio.audioBitrateLabel} ${selectedAudio.displayAudioCodec})';
        }
        return 'Audio Only';

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
          formatSelector = 'bestvideo+bestaudio/best';
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
        final formatSelector = selectedVideo?.formatId ?? (hasSplitVideo ? 'bestvideo' : 'bestvideo/best');
        args.addAll(['-f', formatSelector]);

        if (selectedSubtitles.isNotEmpty) {
          _appendSubtitleFlags(args, selectedSubtitles, embed: true);
        }
        break;

      case DownloadMode.audioOnly:
        final formatSelector = selectedAudio?.formatId ?? 'bestaudio/best';
        args.addAll(['-f', formatSelector, '-x']);
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
}
