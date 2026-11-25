import 'models/media_candidate.dart';
import 'media_probe.dart';

/// Accumulates [MediaCandidate]s reported by the page, de-duplicated and capped.
///
/// Segments and duplicates are dropped here so the UI never shows 300 `.ts`
/// chunks as separate downloads.
class MediaCandidateCollector {
  final MediaProbe probe;
  final int maxCandidates;
  final List<MediaCandidate> _candidates = [];
  final Set<String> _urls = {};

  MediaCandidateCollector({
    this.probe = const MediaProbe(),
    this.maxCandidates = 25,
  });

  List<MediaCandidate> get candidates => List.unmodifiable(_candidates);
  bool get isEmpty => _candidates.isEmpty;
  int get length => _candidates.length;

  /// Classifies and stores [url]; returns the new candidate or null when it was
  /// filtered out or already known.
  MediaCandidate? add({
    required String url,
    String? contentType,
    String? suggestedFilename,
    String? pageTitle,
  }) {
    if (_urls.contains(url)) return null;
    if (_candidates.length >= maxCandidates) return null;
    final candidate = probe.classify(
      url: url,
      contentType: contentType,
      suggestedFilename: suggestedFilename,
      pageTitle: pageTitle,
    );
    if (candidate == null) return null;
    _urls.add(url);
    _candidates.add(candidate);
    return candidate;
  }

  void clear() {
    _candidates.clear();
    _urls.clear();
  }
}
