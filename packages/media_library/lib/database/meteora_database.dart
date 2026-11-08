import 'package:sqlite3/sqlite3.dart';
import '../models/download_task_record.dart';
import '../models/media_item.dart';

/// Persistent local SQLite storage engine for MeteoraDL.
/// Manages download task states and cataloged media items.
class MeteoraDatabase {
  final Database _db;

  MeteoraDatabase._(this._db) {
    _createTables();
  }

  /// Opens an in-memory database instance (ideal for isolated unit tests).
  factory MeteoraDatabase.openInMemory() {
    return MeteoraDatabase._(sqlite3.openInMemory());
  }

  /// Opens a file-backed database instance on disk.
  factory MeteoraDatabase.openFile(String path) {
    return MeteoraDatabase._(sqlite3.open(path));
  }

  Database get rawDatabase => _db;

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS download_tasks (
        task_id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        thumbnail_url TEXT,
        format_label TEXT NOT NULL,
        progress_percent REAL NOT NULL DEFAULT 0.0,
        speed_text TEXT NOT NULL DEFAULT '0 B/s',
        eta_text TEXT NOT NULL DEFAULT '--:--',
        total_size_text TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'queued',
        file_path TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_status ON download_tasks(status);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS media_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        local_file_path TEXT NOT NULL,
        thumbnail_path TEXT,
        media_type TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        resolution TEXT,
        video_codec TEXT,
        audio_codec TEXT,
        bit_rate INTEGER,
        collection TEXT,
        added_at TEXT NOT NULL,
        last_played_at TEXT,
        play_count INTEGER NOT NULL DEFAULT 0,
        playback_position_seconds REAL NOT NULL DEFAULT 0.0
      );
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_media_added ON media_items(added_at DESC);
    ''');
  }

  // ===================== DOWNLOAD TASKS CRUD =====================

  void insertOrUpdateTask(DownloadTaskRecord task) {
    final stmt = _db.prepare('''
      INSERT INTO download_tasks (
        task_id, url, title, thumbnail_url, format_label,
        progress_percent, speed_text, eta_text, total_size_text,
        status, file_path, error_message, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(task_id) DO UPDATE SET
        progress_percent = excluded.progress_percent,
        speed_text = excluded.speed_text,
        eta_text = excluded.eta_text,
        total_size_text = excluded.total_size_text,
        status = excluded.status,
        file_path = excluded.file_path,
        error_message = excluded.error_message;
    ''');

    stmt.execute([
      task.taskId,
      task.url,
      task.title,
      task.thumbnailUrl,
      task.formatLabel,
      task.progressPercent,
      task.speedText,
      task.etaText,
      task.totalSizeText,
      task.status,
      task.filePath,
      task.errorMessage,
      task.createdAt.millisecondsSinceEpoch,
    ]);
    stmt.dispose();
  }

  void updateTaskProgress({
    required String taskId,
    required double percent,
    required String speed,
    required String eta,
    required String totalSize,
    required String status,
  }) {
    final stmt = _db.prepare('''
      UPDATE download_tasks
      SET progress_percent = ?, speed_text = ?, eta_text = ?, total_size_text = ?, status = ?
      WHERE task_id = ?;
    ''');

    stmt.execute([percent, speed, eta, totalSize, status, taskId]);
    stmt.dispose();
  }

  void updateTaskStatus(
    String taskId,
    String status, {
    String? filePath,
    String? errorMessage,
  }) {
    final stmt = _db.prepare('''
      UPDATE download_tasks
      SET status = ?,
          file_path = COALESCE(?, file_path),
          error_message = COALESCE(?, error_message)
      WHERE task_id = ?;
    ''');

    stmt.execute([status, filePath, errorMessage, taskId]);
    stmt.dispose();
  }

  List<DownloadTaskRecord> getAllTasks() {
    final result = _db.select('''
      SELECT * FROM download_tasks ORDER BY created_at DESC;
    ''');

    return result.map((row) => DownloadTaskRecord(
      taskId: row['task_id'] as String,
      url: row['url'] as String,
      title: row['title'] as String,
      thumbnailUrl: row['thumbnail_url'] as String?,
      formatLabel: row['format_label'] as String,
      progressPercent: (row['progress_percent'] as num).toDouble(),
      speedText: row['speed_text'] as String,
      etaText: row['eta_text'] as String,
      totalSizeText: row['total_size_text'] as String,
      status: row['status'] as String,
      filePath: row['file_path'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    )).toList();
  }

  DownloadTaskRecord? getTask(String taskId) {
    final stmt = _db.prepare('SELECT * FROM download_tasks WHERE task_id = ?;');
    final result = stmt.select([taskId]);
    stmt.dispose();

    if (result.isEmpty) return null;
    final row = result.first;
    return DownloadTaskRecord(
      taskId: row['task_id'] as String,
      url: row['url'] as String,
      title: row['title'] as String,
      thumbnailUrl: row['thumbnail_url'] as String?,
      formatLabel: row['format_label'] as String,
      progressPercent: (row['progress_percent'] as num).toDouble(),
      speedText: row['speed_text'] as String,
      etaText: row['eta_text'] as String,
      totalSizeText: row['total_size_text'] as String,
      status: row['status'] as String,
      filePath: row['file_path'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  void deleteTask(String taskId) {
    final stmt = _db.prepare('DELETE FROM download_tasks WHERE task_id = ?;');
    stmt.execute([taskId]);
    stmt.dispose();
  }

  void clearCompletedTasks() {
    _db.execute("DELETE FROM download_tasks WHERE status = 'completed';");
  }

  // ===================== MEDIA ITEMS CRUD =====================

  void insertOrUpdateMediaItem(MediaItem item) {
    final stmt = _db.prepare('''
      INSERT INTO media_items (
        id, title, local_file_path, thumbnail_path, media_type,
        duration_seconds, file_size_bytes, resolution, video_codec,
        audio_codec, bit_rate, collection, added_at, last_played_at,
        play_count, playback_position_seconds
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        local_file_path = excluded.local_file_path,
        thumbnail_path = excluded.thumbnail_path,
        collection = excluded.collection,
        last_played_at = excluded.last_played_at,
        play_count = excluded.play_count,
        playback_position_seconds = excluded.playback_position_seconds;
    ''');

    stmt.execute([
      item.id,
      item.title,
      item.localFilePath,
      item.thumbnailPath,
      item.mediaType.name,
      item.durationSeconds,
      item.fileSizeBytes,
      item.resolution,
      item.videoCodec,
      item.audioCodec,
      item.bitRate,
      item.collection,
      item.addedAt.toIso8601String(),
      item.lastPlayedAt?.toIso8601String(),
      item.playCount,
      item.playbackPositionSeconds,
    ]);
    stmt.dispose();
  }

  List<MediaItem> getAllMediaItems() {
    final result = _db.select('''
      SELECT * FROM media_items ORDER BY added_at DESC;
    ''');

    return result.map((row) => MediaItem(
      id: row['id'] as String,
      title: row['title'] as String,
      localFilePath: row['local_file_path'] as String,
      thumbnailPath: row['thumbnail_path'] as String?,
      mediaType: (row['media_type'] as String) == 'audio'
          ? LibraryMediaType.audio
          : LibraryMediaType.video,
      durationSeconds: row['duration_seconds'] as int,
      fileSizeBytes: row['file_size_bytes'] as int,
      resolution: row['resolution'] as String?,
      videoCodec: row['video_codec'] as String?,
      audioCodec: row['audio_codec'] as String?,
      bitRate: row['bit_rate'] as int?,
      collection: row['collection'] as String?,
      addedAt: DateTime.tryParse(row['added_at'] as String) ?? DateTime.now(),
      lastPlayedAt: row['last_played_at'] != null
          ? DateTime.tryParse(row['last_played_at'] as String)
          : null,
      playCount: row['play_count'] as int,
      playbackPositionSeconds: (row['playback_position_seconds'] as num).toDouble(),
    )).toList();
  }

  MediaItem? getMediaItem(String id) {
    final stmt = _db.prepare('SELECT * FROM media_items WHERE id = ?;');
    final result = stmt.select([id]);
    stmt.dispose();

    if (result.isEmpty) return null;
    final row = result.first;
    return MediaItem(
      id: row['id'] as String,
      title: row['title'] as String,
      localFilePath: row['local_file_path'] as String,
      thumbnailPath: row['thumbnail_path'] as String?,
      mediaType: (row['media_type'] as String) == 'audio'
          ? LibraryMediaType.audio
          : LibraryMediaType.video,
      durationSeconds: row['duration_seconds'] as int,
      fileSizeBytes: row['file_size_bytes'] as int,
      resolution: row['resolution'] as String?,
      videoCodec: row['video_codec'] as String?,
      audioCodec: row['audio_codec'] as String?,
      bitRate: row['bit_rate'] as int?,
      collection: row['collection'] as String?,
      addedAt: DateTime.tryParse(row['added_at'] as String) ?? DateTime.now(),
      lastPlayedAt: row['last_played_at'] != null
          ? DateTime.tryParse(row['last_played_at'] as String)
          : null,
      playCount: row['play_count'] as int,
      playbackPositionSeconds: (row['playback_position_seconds'] as num).toDouble(),
    );
  }

  void updateMediaPlayback(
    String id,
    double positionSeconds, {
    bool incrementPlayCount = false,
  }) {
    final stmt = _db.prepare('''
      UPDATE media_items
      SET playback_position_seconds = ?,
          last_played_at = ?,
          play_count = play_count + ?
      WHERE id = ?;
    ''');

    stmt.execute([
      positionSeconds,
      DateTime.now().toIso8601String(),
      incrementPlayCount ? 1 : 0,
      id,
    ]);
    stmt.dispose();
  }

  void deleteMediaItem(String id) {
    final stmt = _db.prepare('DELETE FROM media_items WHERE id = ?;');
    stmt.execute([id]);
    stmt.dispose();
  }

  void close() {
    _db.dispose();
  }
}
