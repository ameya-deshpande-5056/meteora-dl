import 'package:browser/browser.dart';
import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EngineDownloadBridge', () {
    late InMemoryDownloadEngine engine;

    setUp(() => engine = InMemoryDownloadEngine());
    tearDown(() => engine.dispose());

    test('forwards cookies, UA, referer and headers to the queue', () async {
      final bridge = EngineDownloadBridge(
        engine: engine,
        destinationDirectory: '/downloads',
      );

      await bridge.sendToDownloadManager(
        const BrowserAuthContext(
          url: 'https://example.test/file.zip',
          cookies: 'sid=abc; theme=dark',
          userAgent: 'MeteoraWebView/1.0',
          referer: 'https://example.test/page',
          headers: {'Accept': '*/*'},
          pageTitle: 'Example download',
        ),
      );

      final task = (await engine.listTasks()).single;
      expect(task.request.url, 'https://example.test/file.zip');
      expect(task.request.cookies, 'sid=abc; theme=dark');
      expect(task.request.userAgent, 'MeteoraWebView/1.0');
      expect(task.request.referer, 'https://example.test/page');
      expect(task.request.destinationDirectory, '/downloads');
      expect(task.request.effectiveHeaders(), {
        'Accept': '*/*',
        'Cookie': 'sid=abc; theme=dark',
        'User-Agent': 'MeteoraWebView/1.0',
        'Referer': 'https://example.test/page',
      });
    });

    test('rejects non-http schemes', () async {
      final bridge = EngineDownloadBridge(engine: engine);
      expect(
        () => bridge.sendToDownloadManager(
          const BrowserAuthContext(url: 'javascript:alert(1)'),
        ),
        throwsArgumentError,
      );
      expect(await engine.listTasks(), isEmpty);
    });
  });

  group('MediaProbe', () {
    const probe = MediaProbe();

    test('classifies manifests, media, subtitles and documents', () {
      expect(probe.classify(url: 'https://x.test/master.m3u8')!.kind,
          MediaKind.hls);
      expect(probe.classify(url: 'https://x.test/stream.mpd')!.kind,
          MediaKind.dash);
      expect(
        probe
            .classify(
              url: 'https://x.test/play',
              contentType: 'video/mp4',
            )!
            .kind,
        MediaKind.video,
      );
      expect(probe.classify(url: 'https://x.test/a.srt')!.kind,
          MediaKind.subtitle);
      expect(probe.classify(url: 'https://x.test/doc.pdf')!.kind,
          MediaKind.document);
    });

    test('skips segments, non-http and unknown resources', () {
      expect(probe.classify(url: 'https://x.test/seg-1.m4s'), isNull);
      expect(probe.classify(url: 'https://x.test/chunk.ts'), isNull);
      expect(probe.classify(url: 'blob:https://x.test/abc'), isNull);
      expect(probe.classify(url: 'https://x.test/track?e=1'), isNull);
    });

    test('flags manifests that must go through yt-dlp', () {
      expect(probe.isManifest('https://x.test/master.m3u8?tok=1'), isTrue);
      expect(probe.isManifest('https://x.test/file.mp4'), isFalse);
    });

    test('uses the decoded leaf name as a filename hint', () {
      final candidate = probe.classify(url: 'https://x.test/My%20Song.mp3');
      expect(candidate!.suggestedFilename, 'My Song.mp3');
    });
  });
}
