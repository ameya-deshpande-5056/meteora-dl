enum JsRuntimeType {
  deno,
  quickjs,
}

/// Builds structured yt-dlp argument vectors for a standalone Python runtime.
///
/// The app itself drives downloads through `SimpleDownloadCommandBuilder` and
/// the embedded engine, so this builder is a low-level helper for tests and
/// alternative hosts. It never performs shell interpolation.
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
    String? formatSelector,
    String? mergeOutputFormat,
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
    args.addAll(['-f', formatSelector ?? 'bestvideo+bestaudio/best']);

    // FFmpeg integration for merging
    if (ffmpegPath != null && ffmpegPath!.isNotEmpty) {
      args.addAll(['--ffmpeg-location', ffmpegPath!]);
      args.addAll(['--merge-output-format', mergeOutputFormat ?? 'mp4']);

      if (enableDirectStreamCopy) {
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
