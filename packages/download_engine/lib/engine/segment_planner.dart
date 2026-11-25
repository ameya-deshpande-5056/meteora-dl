/// Plans byte-range segments for a downloadable resource (qtIDM SegmentPlanner concept).
class SegmentPlanner {
  const SegmentPlanner();

  /// Splits [totalBytes] into at most [maxSegments] contiguous segments.
  /// Returns an empty list when totalBytes <= 0 (unknown size -> single stream).
  List<({int start, int end})> plan({
    required int totalBytes,
    required int maxSegments,
  }) {
    if (totalBytes <= 0 || maxSegments <= 1) {
      if (totalBytes > 0) return [(start: 0, end: totalBytes - 1)];
      return const [];
    }
    final segments = <({int start, int end})>[];
    final base = totalBytes ~/ maxSegments;
    var remainder = totalBytes % maxSegments;
    var cursor = 0;
    for (var i = 0; i < maxSegments && cursor < totalBytes; i++) {
      final size = base + (i < remainder ? 1 : 0);
      if (size <= 0) break;
      final end = cursor + size - 1;
      segments.add((start: cursor, end: end.clamp(0, totalBytes - 1)));
      cursor = end + 1;
    }
    return segments;
  }
}