import 'dart:async';

import '../models/download_request.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';

/// Abstract download engine facade. Implementations handle scheduling, segmented
/// HTTP, resume, retry and persistence.
abstract class DownloadEngine {
  Stream<DownloadTask> get taskUpdates;

  Future<DownloadTask> enqueue(DownloadRequest request);

  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);
  Future<void> retry(String taskId);

  Future<List<DownloadTask>> listTasks();
  Future<DownloadTask?> getTask(String taskId);
}

/// A minimal in-memory engine useful for tests and UI wiring. Real Android
/// implementation lives in the native/Kotlin layer and is bridged via platform
/// channels; this keeps the Dart contract testable without native deps.
class InMemoryDownloadEngine implements DownloadEngine {
  final Map<String, DownloadTask> _tasks = {};
  final _controller = StreamController<DownloadTask>.broadcast();
  int _counter = 0;

  @override
  Stream<DownloadTask> get taskUpdates => _controller.stream;

  String _newId() => 'task_${++_counter}';

  @override
  Future<DownloadTask> enqueue(DownloadRequest request) async {
    final task = DownloadTask(id: _newId(), request: request);
    _tasks[task.id] = task;
    _controller.add(task);
    return task;
  }

  @override
  Future<void> pause(String taskId) async {
    final t = _tasks[taskId];
    if (t == null) return;
    if (t.status == DownloadStatus.running ||
        t.status == DownloadStatus.retrying) {
      t.status = DownloadStatus.paused;
      t.touch();
      _controller.add(t);
    }
  }

  @override
  Future<void> resume(String taskId) async {
    final t = _tasks[taskId];
    if (t == null) return;
    if (t.status == DownloadStatus.paused ||
        t.status == DownloadStatus.failed) {
      t.status = DownloadStatus.queued;
      t.touch();
      _controller.add(t);
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    final t = _tasks[taskId];
    if (t == null) return;
    t.status = DownloadStatus.cancelled;
    t.touch();
    _controller.add(t);
  }

  @override
  Future<void> retry(String taskId) async {
    final t = _tasks[taskId];
    if (t == null) return;
    if (t.status.isTerminal && t.status != DownloadStatus.completed) {
      t.status = DownloadStatus.queued;
      t.retryCount += 1;
      t.touch();
      _controller.add(t);
    }
  }

  @override
  Future<List<DownloadTask>> listTasks() async => List.unmodifiable(_tasks.values);

  @override
  Future<DownloadTask?> getTask(String taskId) async => _tasks[taskId];

  void dispose() => _controller.close();
}