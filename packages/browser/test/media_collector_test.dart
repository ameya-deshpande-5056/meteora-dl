import 'package:browser/browser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaCandidateCollector', () {
    test('drops HLS/DASH segments so only the manifest is offered', () {
      final collector = MediaCandidateCollector()
        ..add(url: 'https://x.test/master.m3u8')
        ..add(url: 'https://x.test/seg-00001.ts')
        ..add(url: 'https://x.test/seg-00002.m4s');

      expect(collector.candidates, hasLength(1));
      expect(collector.candidates.single.kind, MediaKind.hls);
    });

    test('de-duplicates repeated reports of the same URL', () {
      final collector = MediaCandidateCollector();
      final first = collector.add(url: 'https://x.test/clip.mp4');
      final second = collector.add(url: 'https://x.test/clip.mp4');

      expect(first, isNotNull);
      expect(second, isNull);
      expect(collector.length, 1);
    });

    test('honours the candidate cap', () {
      final collector = MediaCandidateCollector(maxCandidates: 2);
      collector
        ..add(url: 'https://x.test/a.mp4')
        ..add(url: 'https://x.test/b.mp4')
        ..add(url: 'https://x.test/c.mp4');

      expect(collector.length, 2);
    });

    test('clear resets everything for the next page', () {
      final collector = MediaCandidateCollector()
        ..add(url: 'https://x.test/a.mp4')
        ..clear();

      expect(collector.isEmpty, isTrue);
      expect(collector.add(url: 'https://x.test/a.mp4'), isNotNull);
    });
  });
}
