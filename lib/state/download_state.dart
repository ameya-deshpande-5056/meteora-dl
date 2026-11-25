import 'package:download_engine/download_engine.dart'
    show DirectDownloadPolicy, DownloadRequest;
import 'package:flutter/foundation.dart';
import 'package:media_library/media_library.dart';
import 'package:path_provider/path_provider.dart';
import '../services/direct_download_bridge.dart';
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

  /// Exact yt-dlp argument vector used to start this task. Persisting it is
  /// what makes Retry/Resume possible after a failure or a process restart.
  final List<String>? command;
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
    this.command,
    required this.createdAt,
  });

  bool get canRetry => command != null && command!.isNotEmpty;

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
      command: command,
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
    command: command,
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
      command: record.command,
      createdAt: record.createdAt,
    );
  }
}

class DownloadStateManager extends ChangeNotifier {
  static final DownloadStateManager instance = DownloadStateManager._internal();
  DownloadStateManager._internal();

  static const _firstLaunchSetupKey = 'first_launch_setup_done';

  /// Format label that marks a task as handled by the native segmented HTTP
  /// transport rather than yt-dlp.
  static const String directFormatLabel = 'HTTP Direct';

  static bool isDirectTask(DownloadTask task) =>
      task.formatLabel == directFormatLabel;

  final DirectDownloadPolicy _directPolicy = const DirectDownloadPolicy();

  /// Whether [url] should go through the segmented HTTP engine instead of the
  /// media extractor. Direct files (mp4, zip, pdf, ...) do not need yt-dlp, and
  /// yt-dlp cannot resume them as efficiently as byte ranges can.
  bool shouldUseDirectDownload(String url, {String? contentType, String? fileName}) =>
      _directPolicy.shouldUseDirectTransport(
        url,
        contentType: contentType,
        fileName: fileName,
      );

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

  /// Tasks the badge counts as live work (a paused task is not transferring).
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued).toList();

  /// Everything the Active tab shows: queued, transferring, and paused tasks
  /// waiting to be resumed.
  List<DownloadTask> get inProgressTasks => _tasks
      .where((t) =>
          t.status == TaskStatus.downloading ||
          t.status == TaskStatus.queued ||
          t.status == TaskStatus.paused)
      .toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();

  /// Failed and cancelled tasks. These must stay visible so the user can retry
  /// or dismiss them instead of silently losing the record.
  List<DownloadTask> get failedTasks => _tasks
      .where((t) => t.status == TaskStatus.error || t.status == TaskStatus.cancelled)
      .toList();
  List<MediaItem> get libraryItems => List.unmodifiable(_libraryItems);

  /// Throttling state so progress events do not write to SQLite on every tick.
  final Map<String, int> _lastPersistAtMs = {};
  final Map<String, double> _lastPersistedPercent = {};

  /// Separate throttle for UI rebuilds. yt-dlp emits progress several times a
  /// second; rebuilding every list for each line is what made scrolling stutter.
  final Map<String, int> _lastNotifyAtMs = {};

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
      final previous = _tasks[index];
      final updated = previous.copyWith(
        progressPercent: percent,
        speedText: speed,
        etaText: eta,
        totalSizeText: totalSize,
        status: status,
        filePath: filePath,
        errorMessage: errorMessage,
      );
      _tasks[index] = updated;

      // Persist on state changes and at most once per 1% / 1s of progress. A
      // yt-dlp progress line can arrive several times per second, and writing
      // each one stalls the database without changing what the user sees.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastMs = _lastPersistAtMs[taskId] ?? 0;
      final lastPercent = _lastPersistedPercent[taskId] ?? -100.0;
      final shouldPersist = previous.status != updated.status ||
          updated.progressPercent >= 100.0 ||
          (updated.progressPercent - lastPercent) >= 1.0 ||
          (nowMs - lastMs) >= 1000;

      if (shouldPersist) {
        _database?.updateTaskProgress(
          taskId: taskId,
          percent: percent,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          status: status.name,
          filePath: filePath,
        );
        _lastPersistAtMs[taskId] = nowMs;
        _lastPersistedPercent[taskId] = updated.progressPercent;
      }

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

      final notifyAtMs = DateTime.now().millisecondsSinceEpoch;
      final shouldNotify = previous.status != updated.status ||
          updated.progressPercent >= 100.0 ||
          (notifyAtMs - (_lastNotifyAtMs[taskId] ?? 0)) >= 150;
      if (shouldNotify) {
        _lastNotifyAtMs[taskId] = notifyAtMs;
        notifyListeners();
      }
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
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    final wasDirect = index != -1 && isDirectTask(_tasks[index]);
    _tasks.removeWhere((t) => t.taskId == taskId);
    _lastPersistAtMs.remove(taskId);
    _lastPersistedPercent.remove(taskId);
    _lastNotifyAtMs.remove(taskId);
    _database?.deleteTask(taskId);
    if (wasDirect) {
      // Drops the native queue record and its staging directory; failure here
      // only leaves orphaned bytes, not a broken UI.
      directDownloadEngine.remove(taskId).catchError((Object _) {});
    }
    notifyListeners();
  }

  /// Starts a plain-HTTP download through the native segmented engine.
  ///
  /// The record is created here first so progress events from the service find
  /// a row to update. [headers] carries whatever auth context the caller has
  /// (WebView cookies, user agent, referer); the native side re-validates the
  /// URL before fetching anything.
  Future<bool> startDirectDownload({
    required String url,
    required String title,
    String? fileName,
    String? contentType,
    Map<String, String> headers = const {},
    int expectedBytes = 0,
    int maxSegments = 4,
  }) async {
    if (!shouldUseDirectDownload(
      url,
      contentType: contentType,
      fileName: fileName,
    )) {
      return false;
    }

    final taskId = NativeDirectDownloadEngine.newTaskId();
    final task = DownloadTask(
      taskId: taskId,
      url: url,
      title: title,
      formatLabel: directFormatLabel,
      speedText: 'Queued',
      etaText: 'Queued',
      totalSizeText: expectedBytes > 0 ? _formatBytes(expectedBytes) : '',
      status: TaskStatus.queued,
      createdAt: DateTime.now(),
    );
    addTask(task);

    final request = DownloadRequest(
      url: url,
      suggestedFilename: fileName,
      headers: headers,
      maxRetries: 5,
      expectedBytes: expectedBytes > 0 ? expectedBytes : null,
      maxSegments: maxSegments,
    );

    try {
      await directDownloadEngine.enqueueWithId(taskId, request, title: title);
      return true;
    } catch (e) {
      updateProgress(
        taskId: taskId,
        percent: 0,
        speed: '0 B/s',
        eta: e.toString(),
        totalSize: '',
        status: TaskStatus.error,
        errorMessage: 'Could not start the download service.',
      );
      return false;
    }
  }

  /// Pauses a direct download. The native queue keeps the staged `.part` file,
  /// so resuming continues from the bytes already fetched.
  ///
  /// yt-dlp tasks cannot be paused once started, so they return false.
  Future<bool> pauseTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return false;
    final task = _tasks[index];
    if (!isDirectTask(task)) return false;
    if (task.status != TaskStatus.downloading &&
        task.status != TaskStatus.queued) {
      return false;
    }

    try {
      await directDownloadEngine.pause(taskId);
    } catch (_) {
      return false;
    }

    _tasks[index] = task.copyWith(
      status: TaskStatus.paused,
      speedText: '0 B/s',
      etaText: 'Paused',
    );
    _database?.updateTaskStatus(taskId, 'paused');
    notifyListeners();
    return true;
  }

  static String _formatBytes(int bytes) {
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    final value = bytes.toDouble();
    if (value >= gb) return '${(value / gb).toStringAsFixed(2)} GB';
    if (value >= mb) return '${(value / mb).toStringAsFixed(1)} MB';
    if (value >= kb) return '${(value / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  /// Re-sends the stored yt-dlp argument vector for [taskId], or resumes a
  /// direct download whose ranges are still on disk.
  ///
  /// Returns false when the task is unknown or was created before commands were
  /// persisted, so the UI can explain why nothing happened.
  Future<bool> retryTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return false;

    final task = _tasks[index];
    if (isDirectTask(task)) {
      final resumed = DownloadTask(
        taskId: task.taskId,
        url: task.url,
        title: task.title,
        thumbnailUrl: task.thumbnailUrl,
        formatLabel: task.formatLabel,
        progressPercent: task.progressPercent,
        speedText: 'Queued',
        etaText: 'Queued',
        totalSizeText: task.totalSizeText,
        status: TaskStatus.queued,
        createdAt: task.createdAt,
      );
      _tasks[index] = resumed;
      _lastPersistedPercent[task.taskId] = task.progressPercent - 1;
      _lastPersistAtMs[task.taskId] = 0;
      _database?.insertOrUpdateTask(resumed.toRecord());
      notifyListeners();
      try {
        await directDownloadEngine.resume(taskId);
        return true;
      } catch (_) {
        return false;
      }
    }

    final command = task.command;
    if (command == null || command.isEmpty) return false;

    final restarted = DownloadTask(
      taskId: task.taskId,
      url: task.url,
      title: task.title,
      thumbnailUrl: task.thumbnailUrl,
      formatLabel: task.formatLabel,
      progressPercent: 0.0,
      speedText: 'Connecting...',
      etaText: 'Starting...',
      totalSizeText: task.totalSizeText,
      status: TaskStatus.downloading,
      command: command,
      createdAt: task.createdAt,
    );

    _tasks[index] = restarted;
    _lastPersistedPercent[task.taskId] = -100.0;
    _lastPersistAtMs[task.taskId] = 0;
    _database?.insertOrUpdateTask(restarted.toRecord());
    notifyListeners();

    try {
      return await NativeBridge.startForegroundDownload(
        taskId: restarted.taskId,
        title: restarted.title,
        command: command,
      );
    } catch (_) {
      return false;
    }
  }

  void deleteMediaItem(String id) {
    _libraryItems.removeWhere((item) => item.id == id);
    _database?.deleteMediaItem(id);
    notifyListeners();
  }
}
