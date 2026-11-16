enum PackageType {
  ytdlp(
    displayName: 'yt-dlp',
    repository: 'yt-dlp/yt-dlp',
    executableName: 'yt-dlp',
  ),
  ytdlpEjs(
    displayName: 'yt-dlp-ejs',
    repository: 'yt-dlp/ejs',
    executableName: 'yt-dlp-ejs.bundle.js',
  ),
  deno(
    displayName: 'Deno JS Engine',
    repository: 'denoland/deno',
    executableName: 'deno',
  ),
  quickjsNg(
    displayName: 'QuickJS-NG Engine',
    repository: 'quickjs-ng/quickjs',
    executableName: 'qjs',
  ),
  ffmpeg(
    displayName: 'FFmpeg & FFprobe',
    repository: 'yt-dlp/FFmpeg-Builds',
    executableName: 'ffmpeg',
    additionalExecutableNames: ['ffprobe'],
  );

  /// Human-readable name shown in settings / update UI.
  final String displayName;
  /// GitHub repository (`owner/repo`) whose releases are polled for updates.
  final String repository;
  /// Primary executable file name written into `active/<package>/`.
  final String executableName;
  /// Additional executables shipped in the same package directory (e.g. `ffprobe`
  /// alongside `ffmpeg`). Updated and rolled back atomically together with the primary.
  final List<String> additionalExecutableNames;

  const PackageType({
    required this.displayName,
    required this.repository,
    required this.executableName,
    this.additionalExecutableNames = const [],
  });

  /// Every executable belonging to this package, primary first.
  List<String> get allExecutableNames => <String>[
        executableName,
        ...additionalExecutableNames,
      ];
}
