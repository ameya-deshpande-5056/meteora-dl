import 'package:meta/meta.dart';

/// Kind of media a page exposed while the user was browsing.
enum MediaKind { video, audio, hls, dash, subtitle, image, document, archive, other }

/// A download candidate discovered from a page or an intercepted response.
///
/// Mirrors the capture model qtIDM builds from `webRequest` observations:
/// URL + resolved content type + request context needed to fetch it again
/// outside the page (cookies/UA/referer travel separately).
@immutable
class MediaCandidate {
  final String url;
  final MediaKind kind;
  final String? contentType;
  final String? suggestedFilename;
  final String? pageTitle;

  const MediaCandidate({
    required this.url,
    required this.kind,
    this.contentType,
    this.suggestedFilename,
    this.pageTitle,
  });
}
