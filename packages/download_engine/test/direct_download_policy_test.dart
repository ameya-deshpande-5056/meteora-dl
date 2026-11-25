import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  const policy = DirectDownloadPolicy();

  group('DirectDownloadPolicy', () {
    test('accepts a plain media file URL by extension', () {
      expect(
        policy.shouldUseDirectTransport('https://cdn.example.com/files/clip.mp4'),
        isTrue,
      );
      expect(
        policy.shouldUseDirectTransport('https://cdn.example.com/a/b/album.zip?token=1'),
        isTrue,
      );
    });

    test('accepts an octet-stream or media content type', () {
      expect(
        policy.shouldUseDirectTransport(
          'https://files.example.com/download/9f2',
          contentType: 'application/octet-stream',
        ),
        isTrue,
      );
      expect(
        policy.shouldUseDirectTransport(
          'https://files.example.com/download/9f2',
          contentType: 'video/mp4; charset=binary',
        ),
        isTrue,
      );
    });

    test('rejects pages, manifests and HLS playlists', () {
      expect(
        policy.shouldUseDirectTransport(
          'https://example.com/watch',
          contentType: 'text/html',
        ),
        isFalse,
      );
      expect(
        policy.shouldUseDirectTransport(
          'https://example.com/master.m3u8',
          contentType: 'application/vnd.apple.mpegurl',
        ),
        isFalse,
      );
      expect(
        policy.shouldUseDirectTransport(
          'https://example.com/stream/manifest.mpd',
          contentType: 'application/dash+xml',
        ),
        isFalse,
      );
    });

    test('leaves extractor sites to yt-dlp even for .mp4 URLs', () {
      expect(
        policy.shouldUseDirectTransport('https://www.youtube.com/watch?v=abc'),
        isFalse,
      );
      expect(
        policy.shouldUseDirectTransport('https://youtu.be/abc'),
        isFalse,
      );
      expect(
        policy.shouldUseDirectTransport('https://www.youtube.com/clip.mp4'),
        isFalse,
      );
      expect(
        policy.shouldUseDirectTransport('https://vimeo.com/123456', fileName: 'x.mp4'),
        isFalse,
      );
    });

    test('accepts subdomains of extractor sites', () {
      expect(
        policy.shouldUseDirectTransport('https://m.youtube.com/watch?v=abc'),
        isFalse,
      );
      expect(DirectDownloadPolicy.isExtractorHost('music.youtube.com'), isTrue);
    });

    test('rejects non-http schemes and extension-less unknown URLs', () {
      expect(policy.shouldUseDirectTransport('file:///sdcard/movie.mp4'), isFalse);
      expect(policy.shouldUseDirectTransport('ftp://example.com/movie.mp4'), isFalse);
      expect(
        policy.shouldUseDirectTransport('https://example.com/api/item/42'),
        isFalse,
      );
    });

    test('prefers the file name hint over the URL path', () {
      expect(
        policy.shouldUseDirectTransport(
          'https://example.com/download',
          fileName: 'lecture.mkv',
        ),
        isTrue,
      );
    });
  });
}
