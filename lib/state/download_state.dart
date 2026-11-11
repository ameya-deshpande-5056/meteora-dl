import 'package:flutter/foundation.dart';
import 'package:media_library/media_library.dart';
import 'package:path_provider/path_provider.dart';
import '../services/native_bridge.dart';

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

  DownloadTaskRecord toRecord() => DownloadTaskRecord(
    taskId: taskId,
    url: url,
    title: title,
    thumbnailUrl: thumbnailUrl,
    formatLabel: formatLabel,
    progressPercent: progressPercent,
    speedText: speedText,
    etaText: etaText,
    totalSizeText: totalSizeText,
    status: status.name,
    filePath: filePath,
    errorMessage: errorMessage,
    createdAt: createdAt,
  );

  factory DownloadTask.fromRecord(DownloadTaskRecord record) {
    final taskStatus = TaskStatus.values.firstWhere(
      (s) => s.name == record.status,
      orElse: () => TaskStatus.queued,
    );
    return DownloadTask(
      taskId: record.taskId,
      url: record.url,
      title: record.title,
      thumbnailUrl: record.thumbnailUrl,
      formatLabel: record.formatLabel,
      progressPercent: record.progressPercent,
      speedText: record.speedText,
      etaText: record.etaText,
      totalSizeText: record.totalSizeText,
      status: taskStatus,
      filePath: record.filePath,
      errorMessage: record.errorMessage,
      createdAt: record.createdAt,
    );
  }
}

class DownloadStateManager extends ChangeNotifier {
  static final DownloadStateManager instance = DownloadStateManager._internal();
  DownloadStateManager._internal();

  static const _firstLaunchSetupKey = 'first_launch_setup_done';

  MeteoraDatabase? _database;
  bool _initialized = false;
  DownloadLocationInfo _downloadLocation = DownloadLocationInfo.defaultLocation();

  MeteoraDatabase? get database => _database;
  DownloadLocationInfo get downloadLocation => _downloadLocation;
  bool get isFirstLaunchSetupDone =>
      _database?.getSetting(_firstLaunchSetupKey) == 'true';

  Future<void> refreshDownloadLocation() async {
    _downloadLocation = await NativeBridge.getDownloadLocation();
    notifyListeners();
  }

  Future<DownloadLocationInfo?> pickDownloadLocation() async {
    final picked = await NativeBridge.pickDownloadDirectory();
    if (picked != null) {
      _downloadLocation = picked;
      notifyListeners();
    }
    return picked;
  }

  Future<DownloadLocationInfo> resetDownloadLocation() async {
    final reset = await NativeBridge.resetDownloadLocation();
    _downloadLocation = reset;
    notifyListeners();
    return reset;
  }

  void completeFirstLaunchSetup() {
    _database?.setSetting(_firstLaunchSetupKey, 'true');
    notifyListeners();
  }

  final List<DownloadTask> _tasks = [];
  final List<MediaItem> _libraryItems = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();
  List<MediaItem> get libraryItems => List.unmodifiable(_libraryItems);

  Future<void> init({MeteoraDatabase? db}) async {
    if (_initialized && db == null) return;

    if (db != null) {
      _database = db;
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory()
            .timeout(const Duration(milliseconds: 600));
        final dbPath = '${appDir.path}/meteora.db';
        _database = MeteoraDatabase.openFile(dbPath);
      } catch (_) {
        _database = MeteoraDatabase.openInMemory();
      }
    }

    _initialized = true;

    // Load persisted tasks
    final taskRecords = _database!.getAllTasks();
    _tasks.clear();
    for (final rec in taskRecords) {
      var task = DownloadTask.fromRecord(rec);
      // Unfinished downloads upon app kill are safely marked as paused for retry
      if (task.status == TaskStatus.downloading) {
        task = task.copyWith(status: TaskStatus.paused);
        _database!.updateTaskStatus(task.taskId, 'paused');
      }
      _tasks.add(task);
    }

    // Load persisted media library items
    final mediaRecords = _database!.getAllMediaItems();
    _libraryItems.clear();
    _libraryItems.addAll(mediaRecords);

    notifyListeners();
  }

  void addTask(DownloadTask task) {
    _tasks.insert(0, task);
    _database?.insertOrUpdateTask(task.toRecord());
    notifyListeners();
  }

  void updateProgress({
    required String taskId,
    required double percent,
    required String speed,
    required String eta,
    required String totalSize,
    required TaskStatus status,
    String? filePath,
    String? errorMessage,
  }) {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index != -1) {
      final updated = _tasks[index].copyWith(
        progressPercent: percent,
        speedText: speed,
        etaText: eta,
        totalSizeText: totalSize,
        status: status,
        filePath: filePath,
        errorMessage: errorMessage,
      );
      _tasks[index] = updated;

      _database?.updateTaskProgress(
        taskId: taskId,
        percent: percent,
        speed: speed,
        eta: eta,
        totalSize: totalSize,
        status: status.name,
        filePath: filePath,
      );

      // If completed, add video/audio items to library (avoid misindexing subtitles-only downloads)
      if (status == TaskStatus.completed && !updated.formatLabel.startsWith('Subtitles Only')) {
        final isAudioOnly =
            updated.formatLabel.startsWith('Audio Only') || _isAudioPath(updated.filePath);
        final item = MediaItem(
          id: updated.taskId,
          title: updated.title,
          localFilePath: updated.filePath ?? '',
          thumbnailPath: updated.thumbnailUrl,
          mediaType: isAudioOnly ? LibraryMediaType.audio : LibraryMediaType.video,
          durationSeconds: 0,
          fileSizeBytes: 0,
          resolution: updated.formatLabel,
          addedAt: DateTime.now(),
        );

        _libraryItems.removeWhere((existing) => existing.id == item.id);
        _libraryItems.insert(0, item);
        _database?.insertOrUpdateMediaItem(item);
      }

      notifyListeners();
    }
  }

  static bool _isAudioPath(String? path) {
    if (path == null || path.isEmpty) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac');
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((t) => t.status == TaskStatus.completed);
    _database?.clearCompletedTasks();
    notifyListeners();
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: TaskStatus.cancelled);
      _database?.updateTaskStatus(taskId, 'cancelled');
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.taskId == taskId);
    _database?.deleteTask(taskId);
    notifyListeners();
  }

  void deleteMediaItem(String id) {
    _libraryItems.removeWhere((item) => item.id == id);
    _database?.deleteMediaItem(id);
    notifyListeners();
  }
}
