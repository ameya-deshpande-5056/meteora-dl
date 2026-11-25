import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadTaskStore', () {
    late Directory dir;
    late DownloadTaskStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('meteora_queue_');
      store = DownloadTaskStore(path: '${dir.path}/queue.json');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('round-trips tasks including segments and auth context', () async {
      final task = DownloadTask(
        id: 't1',
        request: const DownloadRequest(
          url: 'https://example.test/file.bin',
          cookies: 'sid=abc',
          userAgent: 'MeteoraTest/1.0',
          referer: 'https://example.test/',
          maxSegments: 4,
        ),
        status: DownloadStatus.paused,
        segments: const [
          Segment(index: 0, start: 0, end: 99, downloaded: 40),
          Segment(index: 1, start: 100, end: 199),
        ],
        totalBytes: 200,
        downloadedBytes: 40,
      );

      await store.save([task]);
      final loaded = await store.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 't1');
      expect(loaded.single.request.cookies, 'sid=abc');
      expect(loaded.single.request.userAgent, 'MeteoraTest/1.0');
      expect(loaded.single.segments, hasLength(2));
      expect(loaded.single.segments.first.downloaded, 40);
      expect(loaded.single.downloadedBytes, 40);
      expect(loaded.single.status, DownloadStatus.paused);
    });

    test('demotes interrupted running tasks to paused on load', () async {
      await store.save([
        DownloadTask(
          id: 'r1',
          request: const DownloadRequest(url: 'https://example.test/a'),
          status: DownloadStatus.running,
        ),
      ]);

      final loaded = await store.load();
      expect(loaded.single.status, DownloadStatus.paused);
      expect(loaded.single.isResumable, isTrue);
    });

    test('quarantines a corrupt queue file instead of throwing', () async {
      await File(store.file.path).writeAsString('{not json');

      expect(await store.load(), isEmpty);
      expect(await File('${store.file.path}.corrupt').exists(), isTrue);
    });

    test('missing file loads as an empty queue', () async {
      expect(await store.load(), isEmpty);
    });
  });
}
