import 'package:media_library/media_library.dart';
import 'package:test/test.dart';

void main() {
  group('MeteoraDatabase SQLite Persistence', () {
    late MeteoraDatabase db;

    setUp(() {
      db = MeteoraDatabase.openInMemory();
    });

    tearDown(() {
      db.close();
    });

    test('creates tables and inserts download task records', () {
      final task = DownloadTaskRecord(
        taskId: 'task_001',
        url: 'https://example.com/video.mp4',
        title: 'Deep Space Exploration',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        formatLabel: '1080p60 (AVC/Opus)',
        progressPercent: 25.5,
        speedText: '4.8 MB/s',
        etaText: '01:15',
        totalSizeText: '120 MB',
        status: 'downloading',
        createdAt: DateTime.now(),
      );

      db.insertOrUpdateTask(task);

      final retrieved = db.getTask('task_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.taskId, equals('task_001'));
      expect(retrieved.title, equals('Deep Space Exploration'));
      expect(retrieved.progressPercent, closeTo(25.5, 0.01));
      expect(retrieved.status, equals('downloading'));
    });

    test('updates task progress in place with ACID isolation', () {
      final task = DownloadTaskRecord(
        taskId: 'task_002',
        url: 'https://example.com/audio.m4a',
        title: 'Podcast Episode 42',
        formatLabel: '160kbps Opus',
        createdAt: DateTime.now(),
      );

      db.insertOrUpdateTask(task);
      db.updateTaskProgress(
        taskId: 'task_002',
        percent: 88.0,
        speed: '12.4 MB/s',
        eta: '00:04',
        totalSize: '45 MB',
        status: 'downloading',
      );

      final updated = db.getTask('task_002');
      expect(updated!.progressPercent, closeTo(88.0, 0.01));
      expect(updated.speedText, equals('12.4 MB/s'));
      expect(updated.etaText, equals('00:04'));
      expect(updated.status, equals('downloading'));
    });

    test('inserts and queries cataloged media items', () {
      final item = MediaItem(
        id: 'media_001',
        title: 'Quantum Computing Lecture',
        localFilePath: '/storage/emulated/0/Movies/Meteora/quantum.mp4',
        thumbnailPath: '/data/user/0/dev.meteora.meteora/cache/thumb_quantum.jpg',
        mediaType: LibraryMediaType.video,
        durationSeconds: 3600,
        fileSizeBytes: 850 * 1024 * 1024,
        resolution: '1920x1080',
        videoCodec: 'av1',
        audioCodec: 'opus',
        bitRate: 1800000,
        collection: 'Physics',
        addedAt: DateTime.now(),
      );

      db.insertOrUpdateMediaItem(item);

      final items = db.getAllMediaItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('Quantum Computing Lecture'));
      expect(items.first.collection, equals('Physics'));
      expect(items.first.videoCodec, equals('av1'));

      // Update playback position
      db.updateMediaPlayback('media_001', 420.5, incrementPlayCount: true);

      final updatedItem = db.getMediaItem('media_001');
      expect(updatedItem!.playbackPositionSeconds, closeTo(420.5, 0.01));
      expect(updatedItem.playCount, equals(1));
      expect(updatedItem.lastPlayedAt, isNotNull);

      // Deletion
      db.deleteMediaItem('media_001');
      expect(db.getAllMediaItems(), isEmpty);
    });

    test('cleans up completed tasks properly', () {
      final t1 = DownloadTaskRecord(
        taskId: 't1',
        url: 'https://example.com/1',
        title: 'Item 1',
        formatLabel: '1080p',
        status: 'completed',
        createdAt: DateTime.now(),
      );
      final t2 = DownloadTaskRecord(
        taskId: 't2',
        url: 'https://example.com/2',
        title: 'Item 2',
        formatLabel: '720p',
        status: 'downloading',
        createdAt: DateTime.now(),
      );

      db.insertOrUpdateTask(t1);
      db.insertOrUpdateTask(t2);

      expect(db.getAllTasks().length, equals(2));

      db.clearCompletedTasks();

      final remaining = db.getAllTasks();
      expect(remaining.length, equals(1));
      expect(remaining.first.taskId, equals('t2'));
    });

    test('persists filePath on progress completion and manages app_settings', () {
      final task = DownloadTaskRecord(
        taskId: 'task_fp',
        url: 'https://example.com/v.mp4',
        title: 'Video',
        formatLabel: 'Video + Audio',
        createdAt: DateTime.now(),
      );
      db.insertOrUpdateTask(task);
      db.updateTaskProgress(
        taskId: 'task_fp',
        percent: 100.0,
        speed: '0 B/s',
        eta: 'Done',
        totalSize: '25.0 MB',
        status: 'completed',
        filePath: 'content://media/external_primary/downloads/42',
      );
      expect(
        db.getTask('task_fp')?.filePath,
        equals('content://media/external_primary/downloads/42'),
      );

      expect(db.getSetting('theme_mode'), isNull);
      db.setSetting('theme_mode', 'amoled');
      expect(db.getSetting('theme_mode'), equals('amoled'));
      db.setSetting('theme_mode', 'dark');
      expect(db.getSetting('theme_mode'), equals('dark'));
      db.deleteSetting('theme_mode');
      expect(db.getSetting('theme_mode'), isNull);
    });
  });
}
