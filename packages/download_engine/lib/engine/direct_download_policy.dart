/// Decides whether a URL is a plain file the segmented HTTP transport should
/// fetch, instead of handing it to the media extractor (yt-dlp).
///
/// Direct HTTP is the right tool only when the URL *is* the payload: a
/// `video/mp4`, a zip, a PDF. A page that merely contains media (YouTube,
/// Vimeo, an HLS manifest) must keep going through the extractor, which knows
/// how to pick formats, merge streams and remux.
class DirectDownloadPolicy {
  const DirectDownloadPolicy();

  /// Sites whose URLs describe a *page* or a segmented stream, never a single
  /// file worth fetching with ranges.
  static const List<String> extractorHosts = [
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'vimeo.com',
    'dailymotion.com',
    'dai.ly',
    'tiktok.com',
    'twitter.com',
    'x.com',
    'instagram.com',
    'facebook.com',
    'fb.watch',
    'reddit.com',
    'redd.it',
    'twitch.tv',
    'soundcloud.com',
    'bandcamp.com',
    'bilibili.com',
    'rumble.com',
    'odysee.com',
    'bitchute.com',
    'streamable.com',
    'spotify.com',
    'pinterest.com',
    'snapchat.com',
    'vk.com',
    'ok.ru',
  ];

  static const Set<String> _manifestMimeTypes = {
    'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
    'audio/mpegurl',
    'audio/x-mpegurl',
    'application/dash+xml',
  };

  static const Set<String> _htmlMimeTypes = {
    'text/html',
    'application/xhtml+xml',
  };

  static const List<String> _directMimePrefixes = [
    'video/',
    'audio/',
    'image/',
    'application/pdf',
    'application/zip',
    'application/x-7z-compressed',
    'application/vnd.rar',
    'application/x-rar-compressed',
    'application/gzip',
    'application/x-tar',
    'application/vnd.android.package-archive',
    'application/epub+zip',
    'text/plain',
    'text/vtt',
    'application/x-subrip',
  ];

  static const Set<String> _binaryMimeTypes = {
    'application/octet-stream',
    'binary/octet-stream',
  };

  /// Extensions that unambiguously name a file rather than a page. Kept narrow
  /// on purpose: guessing from a URL alone is only safe for these.
  static const Set<String> directExtensions = {
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    'flv',
    'm4v',
    'mp3',
    'm4a',
    'aac',
    'opus',
    'ogg',
    'oga',
    'flac',
    'wav',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'pdf',
    'zip',
    '7z',
    'rar',
    'tar',
    'gz',
    'apk',
    'iso',
    'img',
    'epub',
    'srt',
    'vtt',
    'txt',
  };

  static bool isExtractorHost(String host) {
    final normalized = host.toLowerCase();
    return extractorHosts.any(
      (known) => normalized == known || normalized.endsWith('.$known'),
    );
  }

  /// Returns true when [url] should be fetched by [DownloadEngine]'s plain-HTTP
  /// transport. [contentType] and [fileName] are optional hints from a probe or
  /// a capture sheet; without them only an unambiguous file extension makes a
  /// URL eligible.
  bool shouldUseDirectTransport(
    String url, {
    String? contentType,
    String? fileName,
  }) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    if (isExtractorHost(host)) return false;

    final mime = _normalizeMime(contentType);
    if (mime != null) {
      if (_htmlMimeTypes.contains(mime)) return false;
      if (_manifestMimeTypes.contains(mime)) return false;
      if (_binaryMimeTypes.contains(mime)) return true;
      if (_directMimePrefixes.any(mime.startsWith)) return true;
      return false;
    }

    final extension = _extensionOf(fileName) ?? _extensionOf(uri.path);
    return extension != null && directExtensions.contains(extension);
  }

  static String? _normalizeMime(String? raw) {
    if (raw == null) return null;
    final value = raw.split(';').first.trim().toLowerCase();
    return value.isEmpty ? null : value;
  }

  static String? _extensionOf(String? path) {
    if (path == null || path.isEmpty) return null;
    final leaf = path.split('/').last;
    final dot = leaf.lastIndexOf('.');
    if (dot <= 0 || dot == leaf.length - 1) return null;
    return leaf.substring(dot + 1).toLowerCase();
  }
}
