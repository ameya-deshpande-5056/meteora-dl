import 'dart:convert';
import 'dart:io';

import '../models/download_status.dart';
import '../models/download_task.dart';

/// Durable queue persistence for [DownloadTask]s.
///
/// Writes a single JSON document atomically (temp file + rename) so a crash
/// mid-write cannot corrupt the queue. Records are restored on startup with any
/// interrupted task demoted to [DownloadStatus.paused] so it can be resumed
/// instead of silently leaking a "running" ghost.
class DownloadTaskStore {
  final File _file;

  DownloadTaskStore({required String path}) : _file = File(path);

  DownloadTaskStore.withFile(this._file);

  File get file => _file;

  Future<List<DownloadTask>> load() async {
    if (!await _file.exists()) return const [];
    try {
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      final list = decoded is Map<String, dynamic>
          ? decoded['tasks'] as List?
          : decoded as List?;
      if (list == null) return const [];
      return list
          .whereType<Map>()
          .map((e) => DownloadTask.fromJson(e.cast<String, dynamic>()))
          .map(_recoverInterrupted)
          .toList();
    } on FormatException {
      // Corrupt queue: keep the file for inspection and start clean.
      await _quarantineCorrupt();
      return const [];
    }
  }

  Future<void> save(List<DownloadTask> tasks) async {
    final parent = _file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final json = jsonEncode({
      'version': 1,
      'tasks': tasks.map((t) => t.toJson()).toList(),
    });
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(_file.path);
  }

  DownloadTask _recoverInterrupted(DownloadTask task) {
    if (task.status == DownloadStatus.running ||
        task.status == DownloadStatus.retrying) {
      task.status = DownloadStatus.paused;
      task.touch();
    }
    return task;
  }

  Future<void> _quarantineCorrupt() async {
    try {
      await _file.rename('${_file.path}.corrupt');
    } on FileSystemException {
      // Best effort: a locked file should not block startup.
    }
  }
}
