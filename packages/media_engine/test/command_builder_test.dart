import 'package:media_engine/media_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CommandBuilder', () {
    const builder = CommandBuilder(
      pythonPath: '/system/bin/python3',
      ytdlpScriptPath: '/data/user/0/dev.meteora/files/ytdlp/yt-dlp',
      ffmpegPath: '/data/user/0/dev.meteora/files/ffmpeg/ffmpeg',
      jsRuntimePath: '/data/user/0/dev.meteora/files/deno/deno',
      jsRuntimeType: JsRuntimeType.deno,
    );

    test('builds extraction command with safe arguments and js runtime', () {
      final cmd = builder.buildExtractionCommand(url: 'https://youtube.com/watch?v=12345');

      expect(cmd.first, equals('/system/bin/python3'));
      expect(cmd, contains('--dump-single-json'));
      expect(cmd, contains('--js-runtimes'));
      expect(cmd, contains('deno:/data/user/0/dev.meteora/files/deno/deno'));
      expect(cmd.last, equals('https://youtube.com/watch?v=12345'));
    });

    test('builds download command with stream copy and merge flags', () {
      final cmd = builder.buildDownloadCommand(
        url: 'https://youtube.com/watch?v=12345',
        outputDirectory: '/storage/emulated/0/Movies/Meteora',
        outputFilenameTemplate: '%(title)s.%(ext)s',
        formatSelector: '137+140',
        mergeOutputFormat: 'mp4',
      );

      expect(cmd, contains('-f'));
      expect(cmd, contains('137+140'));
      expect(cmd, contains('--ffmpeg-location'));
      expect(cmd, contains('--merge-output-format'));
      expect(cmd, contains('ffmpeg:-c copy -movflags +faststart'));
    });

    test('falls back to bestvideo+bestaudio and mp4 when no selector is given', () {
      final cmd = builder.buildDownloadCommand(
        url: 'https://youtube.com/watch?v=12345',
        outputDirectory: '/tmp',
        outputFilenameTemplate: '%(title)s.%(ext)s',
      );

      expect(cmd, containsAllInOrder(['-f', 'bestvideo+bestaudio/best']));
      expect(cmd, containsAllInOrder(['--merge-output-format', 'mp4']));
    });
  });
}
