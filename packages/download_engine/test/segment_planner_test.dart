import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SegmentPlanner', () {
    const planner = SegmentPlanner();

    test('covers the whole file with no gaps or overlaps', () {
      final segments = planner.plan(totalBytes: 1000, maxSegments: 4);
      expect(segments, hasLength(4));
      expect(segments.first.start, 0);
      expect(segments.last.end, 999);
      var cursor = 0;
      for (final s in segments) {
        expect(s.start, cursor);
        expect(s.end, greaterThanOrEqualTo(s.start));
        cursor = s.end + 1;
      }
      expect(cursor, 1000);
    });

    test('distributes the remainder across the first segments', () {
      final segments = planner.plan(totalBytes: 10, maxSegments: 3);
      expect(segments.map((s) => s.end - s.start + 1), [4, 3, 3]);
    });

    test('returns one segment when the server gave no length', () {
      expect(planner.plan(totalBytes: 0, maxSegments: 8), isEmpty);
      expect(planner.plan(totalBytes: 5, maxSegments: 1), hasLength(1));
    });

    test('never produces empty segments for tiny files', () {
      final segments = planner.plan(totalBytes: 2, maxSegments: 8);
      expect(segments, hasLength(2));
      expect(segments.every((s) => s.end >= s.start), isTrue);
    });
  });
}
