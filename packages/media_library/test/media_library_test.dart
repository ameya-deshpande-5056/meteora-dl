import 'package:media_library/media_library.dart';
import 'package:test/test.dart';

void main() {
  group('FFprobeParser', () {
    test('parses video streams and duration accurately', () {
      final sampleProbe = {
        'format': {
          'duration': '124.50',
          'size': '45120300',
          'bit_rate': '2900000',
        },
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'width': 1920,
            'height': 1080,
          },
          {
            'codec_type': 'audio',
            'codec_name': 'aac',
          }
        ]
      };

      final parsed = FFprobeParser.parseProbeOutput(sampleProbe);
      expect(parsed['media_type'], equals(LibraryMediaType.video));
      expect(parsed['video_codec'], equals('h264'));
      expect(parsed['audio_codec'], equals('aac'));
      expect(parsed['resolution'], equals('1920x1080'));
      expect(parsed['duration_seconds'], equals(125));
      expect(parsed['file_size_bytes'], equals(45120300));
    });

    test('parses audio-only streams accurately', () {
      final sampleAudioProbe = {
        'format': {
          'duration': '210.0',
          'size': '5242880',
        },
        'streams': [
          {
            'codec_type': 'audio',
            'codec_name': 'opus',
          }
        ]
      };

      final parsed = FFprobeParser.parseProbeOutput(sampleAudioProbe);
      expect(parsed['media_type'], equals(LibraryMediaType.audio));
      expect(parsed['video_codec'], isNull);
      expect(parsed['audio_codec'], equals('opus'));
      expect(parsed['duration_seconds'], equals(210));
    });
  });

  group('MediaFilter', () {
    final now = DateTime.now();
    final item1 = MediaItem(
      id: '1',
      title: 'Synthwave Relaxing Mix',
      localFilePath: '/storage/music/synth.mp3',
      mediaType: LibraryMediaType.audio,
      durationSeconds: 3600,
      fileSizeBytes: 80 * 1024 * 1024,
      collection: 'Music',
      addedAt: now.subtract(const Duration(days: 2)),
    );

    final item2 = MediaItem(
      id: '2',
      title: 'Flutter Architecture Masterclass',
      localFilePath: '/storage/movies/flutter.mp4',
      mediaType: LibraryMediaType.video,
      durationSeconds: 1800,
      fileSizeBytes: 400 * 1024 * 1024,
      collection: 'Tutorials',
      addedAt: now.subtract(const Duration(days: 1)),
    );

    final item3 = MediaItem(
      id: '3',
      title: 'Action Movie Trailer 4K',
      localFilePath: '/storage/movies/trailer.mp4',
      mediaType: LibraryMediaType.video,
      durationSeconds: 150,
      fileSizeBytes: 120 * 1024 * 1024,
      collection: 'Trailers',
      addedAt: now,
    );

    final allItems = [item1, item2, item3];

    test('filters by search keyword', () {
      const filter = MediaFilter(searchQuery: 'synthwave');
      final result = filter.apply(allItems);

      expect(result.length, equals(1));
      expect(result.first.id, equals('1'));
    });

    test('filters by media type', () {
      const filter = MediaFilter(typeFilter: LibraryMediaType.video);
      final result = filter.apply(allItems);

      expect(result.length, equals(2));
      expect(result.every((i) => i.mediaType == LibraryMediaType.video), isTrue);
    });

    test('sorts by file size descending', () {
      const filter = MediaFilter(sortOption: SortOption.sizeDesc);
      final result = filter.apply(allItems);

      expect(result.first.id, equals('2')); // 400 MB
      expect(result.last.id, equals('1'));  // 80 MB
    });
  });
}
