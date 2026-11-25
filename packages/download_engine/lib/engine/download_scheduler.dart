import '../models/download_request.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';

/// Concurrency policy for the queue.
class SchedulerPolicy {
  /// Maximum tasks downloading at once.
  final int maxConcurrent;

  /// Maximum simultaneous tasks per host (qtIDM-style per-domain cap to avoid
  /// getting a single site to rate-limit the whole app).
  final int maxPerHost;

  const SchedulerPolicy({this.maxConcurrent = 3, this.maxPerHost = 1});

  String hostOf(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) return '';
    return parsed.host.toLowerCase();
  }
}

/// Decides which queued tasks may start, honouring global and per-host caps.
///
/// The scheduler is pure state (no I/O) so the ordering rules are testable and
/// identical to what the native runner enforces.
class DownloadScheduler {
  final SchedulerPolicy policy;
  final List<DownloadTask> _queue = [];

  DownloadScheduler({this.policy = const SchedulerPolicy()});

  List<DownloadTask> get queue => List.unmodifiable(_queue);

  int get activeCount =>
      _queue.where((t) => t.status == DownloadStatus.running).length;

  void enqueue(DownloadTask task) {
    _queue.removeWhere((t) => t.id == task.id);
    _queue.add(task);
    if (task.status == DownloadStatus.queued) {
      // keep insertion order; nothing else to do
    }
  }

  void remove(String taskId) => _queue.removeWhere((t) => t.id == taskId);

  /// Returns the tasks that should be started right now and flips them to
  /// [DownloadStatus.running] so a second call in the same tick cannot
  /// double-start them.
  List<DownloadTask> nextBatch() {
    final started = <DownloadTask>[];
    var slots = policy.maxConcurrent - activeCount;
    if (slots <= 0) return started;

    final perHost = <String, int>{};
    for (final t in _queue) {
      if (t.status == DownloadStatus.running) {
        final host = policy.hostOf(t.request.url);
        perHost[host] = (perHost[host] ?? 0) + 1;
      }
    }

    for (final task in _queue) {
      if (slots <= 0) break;
      if (task.status != DownloadStatus.queued) continue;
      final host = policy.hostOf(task.request.url);
      if ((perHost[host] ?? 0) >= policy.maxPerHost) continue;
      task.status = DownloadStatus.running;
      task.touch();
      perHost[host] = (perHost[host] ?? 0) + 1;
      started.add(task);
      slots--;
    }
    return started;
  }

  /// Marks a task finished/failed/paused so its slot frees up.
  void finish(String taskId, DownloadStatus status) {
    final task = _queue.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    task.status = status;
    task.touch();
  }

  /// Ordered snapshot of pending work for UI display.
  List<DownloadTask> pending() => _queue
      .where((t) => t.status == DownloadStatus.queued)
      .toList(growable: false);

  /// Moves a queued task ahead of the rest (qtIDM "download now").
  void prioritize(String taskId) {
    final index = _queue.indexWhere((t) => t.id == taskId);
    if (index <= 0) return;
    final task = _queue.removeAt(index);
    _queue.insert(0, task);
  }

  static DownloadTask taskFor(DownloadRequest request, String id) =>
      DownloadTask(id: id, request: request);
}
