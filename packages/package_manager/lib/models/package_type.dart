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
  );

  final String displayName;
  final String repository;
  final String executableName;

  const PackageType({
    required this.displayName,
    required this.repository,
    required this.executableName,
  });
}
