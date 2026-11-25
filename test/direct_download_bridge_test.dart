import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/services/direct_download_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NativeDirectDownloadEngine.channelName);
  late List<MethodCall> calls;
  late StreamController<Map<String, dynamic>> events;

  setUp(() {
    calls = [];
    events = StreamController<Map<String, dynamic>>.broadcast();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'enqueueDirectDownload':
          return true;
        case 'listDirectDownloads':
          return [
            {
              'id': 'direct_1',
              'url': 'https://cdn.example.com/a.mp4',
              'title': 'a.mp4',
              'status': 'paused',
              'totalBytes': 1048576,
              'downloadedBytes': 262144,
              'percent': 25.0,
              'filePath': null,
              'errorMessage': null,
              'fileName': 'a.mp4',
              'segments': [
                {'index': 0, 'start': 0, 'end': 524287, 'downloaded': 262144, 'completed': false},
                {'index': 1, 'start': 524288, 'end': 1048575, 'downloaded': 0, 'completed': false},
              ],
              'createdAt': 1700000000000,
              'updatedAt': 1700000060000,
            },
          ];
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    events.close();
  });

  NativeDirectDownloadEngine newEngine() =>
      NativeDirectDownloadEngine(channel: channel, events: events.stream);

  group('NativeDirectDownloadEngine', () {
    test('enqueue forwards the URL, name and WebView auth headers', () async {
      final engine = newEngine();
      final task = await engine.enqueue(
        const DownloadRequest(
          url: 'https://cdn.example.com/a.mp4',
          suggestedFilename: 'a.mp4',
          cookies: 'sid=abc',
          userAgent: 'MeteoraWebView',
          referer: 'https://example.com/watch',
          expectedBytes: 42,
          maxSegments: 6,
        ),
      );

      expect(task.id, startsWith('direct_'));
      expect(task.status, DownloadStatus.queued);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'enqueueDirectDownload');
      final args = (calls.single.arguments as Map).cast<String, Object?>();
      expect(args['taskId'], task.id);
      expect(args['url'], 'https://cdn.example.com/a.mp4');
      expect(args['fileName'], 'a.mp4');
      expect(args['expectedBytes'], 42);
      expect(args['maxSegments'], 6);
      expect(args['allowResume'], isTrue);
      final headers = (args['headers'] as Map).cast<String, String>();
      expect(headers['Cookie'], 'sid=abc');
      expect(headers['User-Agent'], 'MeteoraWebView');
      expect(headers['Referer'], 'https://example.com/watch');
    });

    test('enqueue reuses a caller-chosen task id', () async {
      final engine = newEngine();
      final task = await engine.enqueueWithId(
        'direct_custom',
        const DownloadRequest(url: 'https://cdn.example.com/b.zip'),
        title: 'Archive',
      );
      expect(task.id, 'direct_custom');
      final args = (calls.single.arguments as Map).cast<String, Object?>();
      expect(args['taskId'], 'direct_custom');
      expect(args['title'], 'Archive');
    });

    test('enqueue surfaces a refused service start', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      final engine = newEngine();
      expect(
        () => engine.enqueue(
          const DownloadRequest(url: 'https://cdn.example.com/a.mp4'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('listTasks maps native ranges and pause state', () async {
      final engine = newEngine();
      final tasks = await engine.listTasks();
      expect(tasks, hasLength(1));
      final task = tasks.single;
      expect(task.id, 'direct_1');
      expect(task.status, DownloadStatus.paused);
      expect(task.totalBytes, 1048576);
      expect(task.downloadedBytes, 262144);
      expect(task.progress, closeTo(0.25, 0.001));
      expect(task.segments, hasLength(2));
      expect(task.segments.last.start, 524288);
      expect(task.segments.first.completed, isFalse);
      expect(task.isResumable, isTrue);
    });

    test('progress events update the tracked task', () async {
      final engine = newEngine();
      final task = await engine.enqueue(
        const DownloadRequest(url: 'https://cdn.example.com/a.mp4'),
      );
      final update = engine.taskUpdates.first;
      events.add({'taskId': task.id, 'status': 'downloading', 'percent': 10.0});
      final updated = await update;
      expect(updated.status, DownloadStatus.running);
      expect(updated.id, task.id);
    });

    test('pause, resume and stop reach the service', () async {
      final engine = newEngine();
      await engine.pause('direct_1');
      await engine.resume('direct_1');
      await engine.cancel('direct_1');
      expect(
        calls.map((c) => c.method),
        ['pauseDirectDownload', 'resumeDirectDownload', 'cancelDownload'],
      );
    });
  });
}
