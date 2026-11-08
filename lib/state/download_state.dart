import 'package:flutter/foundation.dart';
import 'package:media_library/media_library.dart';

enum TaskStatus {
  queued,
  downloading,
  paused,
  completed,
  cancelled,
  error;

  String get label {
    switch (this) {
      case TaskStatus.queued: return 'Queued';
      case TaskStatus.downloading: return 'Downloading';
      case TaskStatus.paused: return 'Paused';
      case TaskStatus.completed: return 'Completed';
      case TaskStatus.cancelled: return 'Cancelled';
      case TaskStatus.error: return 'Failed';
    }
  }
}

class DownloadTask {
  final String taskId;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String formatLabel;
  final double progressPercent;
  final String speedText;
  final String etaText;
  final String totalSizeText;
  final TaskStatus status;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;

  const DownloadTask({
    required this.taskId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    required this.formatLabel,
    this.progressPercent = 0.0,
    this.speedText = '0 B/s',
    this.etaText = '--:--',
    this.totalSizeText = '',
    this.status = TaskStatus.queued,
    this.filePath,
    this.errorMessage,
    required this.createdAt,
  });

  DownloadTask copyWith({
    double? progressPercent,
    String? speedText,
    String? etaText,
    String? totalSizeText,
    TaskStatus? status,
    String? filePath,
    String? errorMessage,
  }) {
    return DownloadTask(
      taskId: taskId,
      url: url,
      title: title,
      thumbnailUrl: thumbnailUrl,
      formatLabel: formatLabel,
      progressPercent: progressPercent ?? this.progressPercent,
      speedText: speedText ?? this.speedText,
      etaText: etaText ?? this.etaText,
      totalSizeText: totalSizeText ?? this.totalSizeText,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }
}

class DownloadStateManager extends ChangeNotifier {
  static final DownloadStateManager instance = DownloadStateManager._internal();
  DownloadStateManager._internal();

  final List<DownloadTask> _tasks = [];
  final List<MediaItem> _libraryItems = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();
  List<MediaItem> get libraryItems => List.unmodifiable(_libraryItems);

  void addTask(DownloadTask task) {
    _tasks.insert(0, task);
    notifyListeners();
  }

  void updateProgress({
    required String taskId,
    required double percent,
    required String speed,
    required String eta,
    required String totalSize,
    required TaskStatus status,
  }) {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index != -1) {
      final updated = _tasks[index].copyWith(
        progressPercent: percent,
        speedText: speed,
        etaText: eta,
        totalSizeText: totalSize,
        status: status,
      );
      _tasks[index] = updated;

      // If completed, add to library
      if (status == TaskStatus.completed) {
        _libraryItems.insert(
          0,
          MediaItem(
            id: updated.taskId,
            title: updated.title,
            localFilePath: updated.filePath ?? '',
            thumbnailPath: updated.thumbnailUrl,
            mediaType: updated.formatLabel.contains('Audio') ? LibraryMediaType.audio : LibraryMediaType.video,
            durationSeconds: 0,
            fileSizeBytes: 0,
            resolution: updated.formatLabel,
            addedAt: DateTime.now(),
          ),
        );
      }

      notifyListeners();
    }
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: TaskStatus.cancelled);
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.taskId == taskId);
    notifyListeners();
  }
}
