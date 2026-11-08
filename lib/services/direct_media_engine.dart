import 'dart:async';
import 'dart:io';
import 'package:media_engine/media_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../state/download_state.dart';
import 'native_bridge.dart';

class DirectMediaEngine {
  static final DirectMediaEngine instance = DirectMediaEngine._internal();
  DirectMediaEngine._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, StreamSubscription<List<int>>> _activeDownloads = {};

  bool isSupported(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  Future<MediaInfo?> extractVideo(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);

    final formatList = <FormatInfo>[];

    // Muxed streams (both video & audio combined, ready for immediate playback)
    for (final s in manifest.muxed) {
      formatList.add(FormatInfo(
        formatId: 'muxed_${s.tag}',
        formatNote: '${s.qualityLabel} (Video + Audio)',
        ext: s.container.name,
        width: s.videoResolution.width,
        height: s.videoResolution.height,
        fps: s.framerate.framesPerSecond.toDouble(),
        vcodec: s.videoCodec,
        acodec: s.audioCodec,
        filesize: s.size.totalBytes,
        streamType: StreamType.combined,
      ));
    }

    // Video only streams (high resolutions: 1080p, 1440p, 4K)
    for (final s in manifest.videoOnly) {
      formatList.add(FormatInfo(
        formatId: 'video_${s.tag}',
        formatNote: '${s.qualityLabel} (${s.videoCodec})',
        ext: s.container.name,
        width: s.videoResolution.width,
        height: s.videoResolution.height,
        fps: s.framerate.framesPerSecond.toDouble(),
        vcodec: s.videoCodec,
        filesize: s.size.totalBytes,
        streamType: StreamType.videoOnly,
      ));
    }

    // Audio only streams (Opus, M4A)
    for (final s in manifest.audioOnly) {
      formatList.add(FormatInfo(
        formatId: 'audio_${s.tag}',
        formatNote: '${s.bitrate.kiloBitsPerSecond.round()} kbps (${s.audioCodec})',
        ext: s.container.name,
        acodec: s.audioCodec,
        abr: s.bitrate.kiloBitsPerSecond.roundToDouble(),
        filesize: s.size.totalBytes,
        streamType: StreamType.audioOnly,
      ));
    }

    return MediaInfo(
      id: video.id.value,
      title: video.title,
      uploader: video.author,
      durationSeconds: video.duration?.inSeconds,
      thumbnail: video.thumbnails.highResUrl,
      webpageUrl: video.url,
      extractor: 'YouTube Direct Engine',
      description: video.description,
      formats: formatList,
    );
  }

  Future<PlaylistInfo?> extractPlaylist(String url) async {
    final playlist = await _yt.playlists.get(url);
    final videos = await _yt.playlists.getVideos(playlist.id).take(50).toList();

    return PlaylistInfo(
      id: playlist.id.value,
      title: playlist.title,
      uploader: playlist.author,
      description: playlist.description,
      itemCount: videos.length,
      entries: videos.map((v) => PlaylistEntry(
        id: v.id.value,
        title: v.title,
        url: v.url,
        uploader: v.author,
        durationSeconds: v.duration?.inSeconds,
        thumbnail: v.thumbnails.highResUrl,
      )).toList(),
    );
  }

  Future<void> startDownload({
    required String taskId,
    required String videoUrl,
    required String title,
    String? thumbnailUrl,
    required String formatId,
    required String formatLabel,
  }) async {
    try {
      final video = await _yt.videos.get(videoUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Select optimal target stream
      StreamInfo streamInfo;
      if (formatId.startsWith('audio_')) {
        final tag = int.tryParse(formatId.replaceFirst('audio_', ''));
        streamInfo = manifest.audioOnly.firstWhere(
          (s) => s.tag == tag,
          orElse: () => manifest.audioOnly.reduce((a, b) => a.bitrate.kiloBitsPerSecond > b.bitrate.kiloBitsPerSecond ? a : b),
        );
      } else if (formatId.startsWith('video_')) {
        final tag = int.tryParse(formatId.replaceFirst('video_', ''));
        streamInfo = manifest.videoOnly.firstWhere(
          (s) => s.tag == tag,
          orElse: () => manifest.videoOnly.reduce((a, b) => a.videoResolution.height > b.videoResolution.height ? a : b),
        );
      } else if (formatId.startsWith('muxed_')) {
        final tag = int.tryParse(formatId.replaceFirst('muxed_', ''));
        streamInfo = manifest.muxed.firstWhere(
          (s) => s.tag == tag,
          orElse: () => manifest.muxed.reduce((a, b) => a.videoResolution.height > b.videoResolution.height ? a : b),
        );
      } else {
        streamInfo = manifest.muxed.isNotEmpty
            ? manifest.muxed.reduce((a, b) => a.videoResolution.height > b.videoResolution.height ? a : b)
            : manifest.video.first;
      }

      final ext = streamInfo.container.name;
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final appDir = await getApplicationDocumentsDirectory();
      final localDir = Directory('${appDir.path}/downloads');
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      final targetFile = File('${localDir.path}/${sanitizedTitle}_$taskId.$ext');

      final stream = _yt.videos.streamsClient.get(streamInfo);
      final output = targetFile.openWrite();
      final totalBytes = streamInfo.size.totalBytes;
      var receivedBytes = 0;
      final stopwatch = Stopwatch()..start();

      final subscription = stream.listen(
        (chunk) {
          output.add(chunk);
          receivedBytes += chunk.length;

          final percent = totalBytes > 0 ? (receivedBytes / totalBytes) * 100 : 0.0;
          final seconds = stopwatch.elapsedMilliseconds / 1000;
          final speedBytesPerSec = seconds > 0 ? (receivedBytes / seconds) : 0.0;
          final speedText = '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
          final remainingBytes = totalBytes - receivedBytes;
          final etaSeconds = speedBytesPerSec > 0 ? (remainingBytes / speedBytesPerSec).round() : 0;
          final etaText = '${(etaSeconds ~/ 60).toString().padLeft(2, '0')}:${(etaSeconds % 60).toString().padLeft(2, '0')}';
          final totalSizeText = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

          DownloadStateManager.instance.updateProgress(
            taskId: taskId,
            percent: percent,
            speed: speedText,
            eta: etaText,
            totalSize: totalSizeText,
            status: TaskStatus.downloading,
          );
        },
        onError: (e) async {
          await output.flush();
          await output.close();
          _activeDownloads.remove(taskId);
          DownloadStateManager.instance.updateProgress(
            taskId: taskId,
            percent: 0.0,
            speed: '0 B/s',
            eta: '--:--',
            totalSize: '',
            status: TaskStatus.error,
          );
        },
        onDone: () async {
          await output.flush();
          await output.close();
          _activeDownloads.remove(taskId);

          DownloadStateManager.instance.updateProgress(
            taskId: taskId,
            percent: 100.0,
            speed: '0 B/s',
            eta: 'Complete',
            totalSize: '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            status: TaskStatus.completed,
          );

          // Publish to MediaStore for public accessibility
          try {
            await NativeBridge.publishToMediaStore(
              filePath: targetFile.path,
              displayName: '$sanitizedTitle.$ext',
              mimeType: ext == 'mp4' ? 'video/mp4' : (ext == 'webm' ? 'video/webm' : 'audio/mp4'),
              isVideo: !formatLabel.contains('Audio'),
            );
          } catch (_) {}
        },
        cancelOnError: true,
      );

      _activeDownloads[taskId] = subscription;
    } catch (e) {
      DownloadStateManager.instance.updateProgress(
        taskId: taskId,
        percent: 0.0,
        speed: '0 B/s',
        eta: '--:--',
        totalSize: '',
        status: TaskStatus.error,
      );
    }
  }

  void cancelDownload(String taskId) {
    _activeDownloads[taskId]?.cancel();
    _activeDownloads.remove(taskId);
    DownloadStateManager.instance.cancelTask(taskId);
  }
}
