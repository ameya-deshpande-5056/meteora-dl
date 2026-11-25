import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

DownloadTask task(String id, String url) => DownloadTask(
      id: id,
      request: DownloadRequest(url: url),
    );

void main() {
  group('DownloadScheduler', () {
    test('respects the global concurrency cap', () {
      final scheduler = DownloadScheduler(
        policy: const SchedulerPolicy(maxConcurrent: 2, maxPerHost: 2),
      );
      scheduler
        ..enqueue(task('a', 'https://a.test/1'))
        ..enqueue(task('b', 'https://b.test/1'))
        ..enqueue(task('c', 'https://c.test/1'));

      expect(scheduler.nextBatch().map((t) => t.id), ['a', 'b']);
      // Second call in the same tick must not double-start anything.
      expect(scheduler.nextBatch(), isEmpty);

      scheduler.finish('a', DownloadStatus.completed);
      expect(scheduler.nextBatch().map((t) => t.id), ['c']);
    });

    test('caps tasks per host', () {
      final scheduler = DownloadScheduler(
        policy: const SchedulerPolicy(maxConcurrent: 5, maxPerHost: 1),
      );
      scheduler
        ..enqueue(task('a', 'https://same.test/1'))
        ..enqueue(task('b', 'https://same.test/2'))
        ..enqueue(task('c', 'https://other.test/1'));

      expect(scheduler.nextBatch().map((t) => t.id), ['a', 'c']);
      expect(scheduler.pending().map((t) => t.id), ['b']);
    });

    test('prioritize moves a queued task to the front', () {
      final scheduler = DownloadScheduler(
        policy: const SchedulerPolicy(maxConcurrent: 1, maxPerHost: 1),
      );
      scheduler
        ..enqueue(task('a', 'https://a.test/1'))
        ..enqueue(task('b', 'https://b.test/1'))
        ..enqueue(task('c', 'https://c.test/1'));

      scheduler.prioritize('c');
      expect(scheduler.nextBatch().single.id, 'c');
    });

    test('finish frees the slot and marks the status', () {
      final scheduler = DownloadScheduler();
      final t = task('a', 'https://a.test/1');
      scheduler.enqueue(t);
      scheduler.nextBatch();
      expect(scheduler.activeCount, 1);

      scheduler.finish('a', DownloadStatus.failed);
      expect(scheduler.activeCount, 0);
      expect(t.status, DownloadStatus.failed);
    });
  });
}
