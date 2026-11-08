import '../models/format_recommendation.dart';

enum JsRuntimeType {
  deno,
  quickjs,
}

class CommandBuilder {
  final String pythonPath;
  final String ytdlpScriptPath;
  final String? ffmpegPath;
  final String? jsRuntimePath;
  final JsRuntimeType jsRuntimeType;

  const CommandBuilder({
    required this.pythonPath,
    required this.ytdlpScriptPath,
    this.ffmpegPath,
    this.jsRuntimePath,
    this.jsRuntimeType = JsRuntimeType.deno,
  });

  List<String> buildExtractionCommand({
    required String url,
    bool flatPlaylist = false,
  }) {
    final args = <String>[
      pythonPath,
      ytdlpScriptPath,
      '--dump-single-json',
      '--no-warnings',
      '--no-call-home',
      '--skip-download',
    ];

    if (flatPlaylist) {
      args.add('--flat-playlist');
    }

    _appendJsRuntimeArgs(args);
    args.addAll(['--', url.trim()]);
    return args;
  }

  List<String> buildDownloadCommand({
    required String url,
    required String outputDirectory,
    required String outputFilenameTemplate,
    FormatRecommendation? recommendation,
    String? customFormatSelector,
    bool enableDirectStreamCopy = true,
  }) {
    final args = <String>[
      pythonPath,
      ytdlpScriptPath,
      '--no-warnings',
      '--continue',
      '--retries', '5',
      '--fragment-retries', '10',
      '--output', '$outputDirectory/$outputFilenameTemplate',
    ];

    // Format selection
    final formatStr = customFormatSelector ?? recommendation?.ytdlpFormatSelector ?? 'bestvideo+bestaudio/best';
    args.addAll(['-f', formatStr]);

    // FFmpeg integration for merging
    if (ffmpegPath != null && ffmpegPath!.isNotEmpty) {
      args.addAll(['--ffmpeg-location', ffmpegPath!]);
      final targetExt = recommendation?.targetExtension ?? 'mp4';
      args.addAll(['--merge-output-format', targetExt]);

      if (enableDirectStreamCopy && (recommendation?.directStreamCopyPossible ?? true)) {
        args.addAll(['--postprocessor-args', 'ffmpeg:-c copy -movflags +faststart']);
      }
    }

    _appendJsRuntimeArgs(args);
    args.addAll(['--', url.trim()]);
    return args;
  }

  void _appendJsRuntimeArgs(List<String> args) {
    if (jsRuntimePath != null && jsRuntimePath!.isNotEmpty) {
      final runtimeFlag = jsRuntimeType == JsRuntimeType.deno ? 'deno' : 'quickjs';
      args.addAll([
        '--js-runtimes',
        '$runtimeFlag:$jsRuntimePath',
        '--remote-components',
        'ejs:github',
      ]);
    }
  }
}
