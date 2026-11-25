import 'models/media_candidate.dart';

/// Classifies page/resource URLs into download candidates.
///
/// Adapted from qtIDM's capture heuristics (manifest detection, direct media
/// content types, subtitle and segment filtering) but kept as pure functions so
/// the rules are testable without a WebView.
class MediaProbe {
  const MediaProbe();

  static final RegExp _hls = RegExp(r'\.m3u8(?:$|[?#])', caseSensitive: false);
  static final RegExp _dash = RegExp(r'\.mpd(?:$|[?#])', caseSensitive: false);
  static final RegExp _segment = RegExp(
    r'\.(?:ts|m4s|aac|key)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _subtitle = RegExp(
    r'\.(?:vtt|srt|ass|ssa|ttml)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _video = RegExp(
    r'\.(?:mp4|m4v|webm|mkv|mov|avi|flv|3gp)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _audio = RegExp(
    r'\.(?:mp3|m4a|aac|opus|ogg|oga|flac|wav)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _image = RegExp(
    r'\.(?:png|jpe?g|webp|gif|avif)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _document = RegExp(
    r'\.(?:pdf|epub|csv|txt|json)(?:$|[?#])',
    caseSensitive: false,
  );
  static final RegExp _archive = RegExp(
    r'\.(?:zip|tar|gz|tgz|7z|rar)(?:$|[?#])',
    caseSensitive: false,
  );

  /// Returns a candidate for [url], or null when it is not worth offering
  /// (HLS/DASH segments, telemetry, non-http schemes, blob URLs).
  MediaCandidate? classify({
    required String url,
    String? contentType,
    String? suggestedFilename,
    String? pageTitle,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    // fMP4/HLS segments are parts of a manifest, never standalone downloads.
    if (_segment.hasMatch(url)) return null;

    final type = (contentType ?? '').toLowerCase();
    final kind = _kindFor(url, type);
    if (kind == null) return null;

    return MediaCandidate(
      url: url,
      kind: kind,
      contentType: contentType,
      suggestedFilename: suggestedFilename ?? _leafName(uri),
      pageTitle: pageTitle,
    );
  }

  /// True when [url] points at an adaptive manifest the engine must hand to
  /// yt-dlp rather than to the plain HTTP path.
  bool isManifest(String url) => _hls.hasMatch(url) || _dash.hasMatch(url);

  MediaKind? _kindFor(String url, String contentType) {
    if (_dash.hasMatch(url) || contentType.contains('dash+xml')) {
      return MediaKind.dash;
    }
    if (_hls.hasMatch(url) || contentType.contains('mpegurl')) {
      return MediaKind.hls;
    }
    if (contentType.startsWith('video/') || _video.hasMatch(url)) {
      return MediaKind.video;
    }
    if (contentType.startsWith('audio/') || _audio.hasMatch(url)) {
      return MediaKind.audio;
    }
    if (_subtitle.hasMatch(url) ||
        contentType.contains('text/vtt') ||
        contentType.contains('ttml') ||
        contentType.contains('subrip') ||
        contentType.contains('x-ssa')) {
      return MediaKind.subtitle;
    }
    if (_image.hasMatch(url) || contentType.startsWith('image/')) {
      return MediaKind.image;
    }
    if (_document.hasMatch(url) || contentType == 'application/pdf') {
      return MediaKind.document;
    }
    if (_archive.hasMatch(url)) return MediaKind.archive;
    return null;
  }

  String? _leafName(Uri uri) {
    if (uri.pathSegments.isEmpty) return null;
    final leaf = uri.pathSegments.last.trim();
    if (leaf.isEmpty) return null;
    try {
      return Uri.decodeComponent(leaf);
    } on ArgumentError {
      return leaf;
    }
  }
}
