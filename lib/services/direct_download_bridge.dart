import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';

import 'native_bridge.dart';

/// Cookie + user agent of the in-app WebView, read natively from Android's
/// `CookieManager`. This is the auth context that makes harvesting a URL from
/// the built-in browser different from pasting it into another app.
class WebViewAuthContext {
  const WebViewAuthContext({this.userAgent, this.cookie});

  final String? userAgent;
  final String? cookie;

  bool get hasCookies => cookie != null && cookie!.isNotEmpty;

  factory WebViewAuthContext.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const WebViewAuthContext();
    return WebViewAuthContext(
      userAgent: (map['userAgent'] as String?)?.trim(),
      cookie: map['cookie'] as String?,
    );
  }
}

/// Dart facade over the native [DownloadEngine] implementation.
///
/// The authoritative queue lives in `DownloadForegroundService`
/// (`DirectDownloadQueue` in Kotlin): it survives the activity, keeps the
/// per-range resume state and owns scheduling. This class only translates
/// [DownloadRequest]s into channel calls and native snapshots back into the
/// package's models, so the UI layer never has to know the wire format.
class NativeDirectDownloadEngine implements DownloadEngine {
  NativeDirectDownloadEngine({
    MethodChannel? channel,
    Stream<Map<String, dynamic>>? events,
  })  : _channel = channel ?? const MethodChannel('dev.meteora/engine'),
        _events = events ?? NativeBridge.downloadEvents {
    _subscription = _events.listen(_onEvent, onError: (Object _) {});
  }

  static const String channelName = 'dev.meteora/engine';

  final MethodChannel _channel;
  final Stream<Map<String, dynamic>> _events;
  final StreamController<DownloadTask> _controller =
      StreamController<DownloadTask>.broadcast();
  final Map<String, DownloadTask> _tasks = {};

  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  Stream<DownloadTask> get taskUpdates => _controller.stream;

  /// Unique id in the same shape the native side sanitises into a file name.
  static String newTaskId([DateTime? now]) =>
      'direct_${(now ?? DateTime.now()).microsecondsSinceEpoch}';

  /// Payload for the native enqueue call. Pure so it can be asserted in tests.
  static Map<String, Object?> buildEnqueueArguments({
    required String taskId,
    required DownloadRequest request,
    String? title,
  }) {
    return {
      'taskId': taskId,
      'url': request.url,
      'title': title ?? request.suggestedFilename ?? _leafName(request.url),
      'fileName': request.suggestedFilename,
      'headers': request.effectiveHeaders(),
      'expectedBytes': request.expectedBytes ?? 0,
      'maxSegments': request.maxSegments,
      'allowResume': request.allowResume,
    };
  }

  static String _leafName(String url) {
    final uri = Uri.tryParse(url);
    final leaf = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : url.split('/').last;
    return leaf.isEmpty ? url : leaf;
  }

  @override
  Future<DownloadTask> enqueue(DownloadRequest request) =>
      enqueueWithId(newTaskId(), request);

  /// Same as [enqueue] but with a caller-chosen id, so the app's persisted task
  /// row and the native queue entry share one identity.
  Future<DownloadTask> enqueueWithId(
    String taskId,
    DownloadRequest request, {
    String? title,
  }) async {
    final started = await _channel.invokeMethod<bool>(
      'enqueueDirectDownload',
      buildEnqueueArguments(taskId: taskId, request: request, title: title),
    );
    if (started != true) {
      throw StateError('The download service refused the request');
    }
    final task = DownloadTask(
      id: taskId,
      request: request,
      status: DownloadStatus.queued,
    );
    _tasks[taskId] = task;
    _controller.add(task);
    return task;
  }

  @override
  Future<void> pause(String taskId) async {
    await _channel.invokeMethod<bool>('pauseDirectDownload', {
      'taskId': taskId,
    });
  }

  @override
  Future<void> resume(String taskId) async {
    await _channel.invokeMethod<bool>('resumeDirectDownload', {
      'taskId': taskId,
    });
  }

  /// Cancelling a direct download uses the service's shared cancel action,
  /// which clears both the native queue entry and the staged `.part` file.
  @override
  Future<void> cancel(String taskId) async {
    await _channel.invokeMethod<bool>('cancelDownload', {'taskId': taskId});
  }

  @override
  Future<void> retry(String taskId) async {
    _tasks[taskId]?.retryCount += 1;
    await resume(taskId);
  }

  /// Removes the queue record and its staging directory.
  Future<void> remove(String taskId) async {
    _tasks.remove(taskId);
    await _channel.invokeMethod<bool>('removeDirectDownload', {
      'taskId': taskId,
    });
  }

  @override
  Future<List<DownloadTask>> listTasks() async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'listDirectDownloads',
    );
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => _taskFromNative(entry.cast<String, dynamic>()))
        .toList();
  }

  /// Cookie + user agent the in-app WebView currently has for [url].
  /// Returns an empty context when the platform is unavailable.
  Future<WebViewAuthContext> authContextFor(String url) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getWebViewAuthContext',
        {'url': url},
      );
      return WebViewAuthContext.fromMap(res);
    } catch (_) {
      return const WebViewAuthContext();
    }
  }

  @override
  Future<DownloadTask?> getTask(String taskId) async {
    final cached = _tasks[taskId];
    if (cached != null) return cached;
    final tasks = await listTasks();
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
    return _tasks[taskId];
  }

  void _onEvent(Map<String, dynamic> event) {
    final taskId = event['taskId'] as String?;
    if (taskId == null || taskId.isEmpty) return;
    final task = _tasks[taskId];
    if (task == null) return; // Recorded by another layer; nothing to update.

    final status = _statusFromWire(event['status'] as String?);
    task.status = status;
    if (event['percent'] is num && event['totalSize'] is String) {
      final total = task.totalBytes;
      if (total > 0) {
        task.downloadedBytes =
            ((event['percent'] as num).toDouble() / 100.0 * total).round();
      }
    }
    final filePath = event['filePath'] as String?;
    if (filePath != null && filePath.isNotEmpty) task.filePath = filePath;
    final eta = event['eta'] as String?;
    if (status == DownloadStatus.failed && eta != null && eta.isNotEmpty) {
      task.errorMessage = eta;
    }
    task.touch();
    _controller.add(task);
  }

  static DownloadStatus _statusFromWire(String? wire) {
    switch (wire) {
      case 'queued':
        return DownloadStatus.queued;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'error':
      case 'failed':
        return DownloadStatus.failed;
      case 'cancelled':
        return DownloadStatus.cancelled;
      case 'downloading':
      case 'running':
      default:
        return DownloadStatus.running;
    }
  }

  static DownloadTask _taskFromNative(Map<String, dynamic> map) {
    final url = map['url'] as String? ?? '';
    final segmentsJson = map['segments'];
    final segments = segmentsJson is List
        ? segmentsJson
            .whereType<Map>()
            .map(
              (raw) => Segment(
                index: (raw['index'] as num?)?.toInt() ?? 0,
                start: (raw['start'] as num?)?.toInt() ?? 0,
                end: (raw['end'] as num?)?.toInt() ?? 0,
                downloaded: (raw['downloaded'] as num?)?.toInt() ?? 0,
                completed: raw['completed'] as bool? ?? false,
              ),
            )
            .toList()
        : <Segment>[];

    final createdAtMs = (map['createdAt'] as num?)?.toInt() ?? 0;
    final updatedAtMs = (map['updatedAt'] as num?)?.toInt() ?? createdAtMs;

    return DownloadTask(
      id: map['id'] as String? ?? '',
      request: DownloadRequest(
        url: url,
        suggestedFilename: map['fileName'] as String?,
      ),
      status: _statusFromWire(map['status'] as String?),
      segments: segments,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      filePath: map['filePath'] as String?,
      errorMessage: map['errorMessage'] as String?,
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      updatedAt: updatedAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
          : DateTime.now(),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Shared engine instance for the app (the native service is a singleton too).
NativeDirectDownloadEngine? _engine;

NativeDirectDownloadEngine get directDownloadEngine =>
    _engine ??= NativeDirectDownloadEngine();
