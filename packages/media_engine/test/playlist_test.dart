import 'package:media_engine/media_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PlaylistInfo', () {
    test('parses playlist manifest with entries accurately', () {
      final json = {
        'id': 'PL1234567890',
        'title': 'Flutter Architecture Deep Dive Series',
        'uploader': 'Tech Talks',
        'description': 'A collection of masterclasses on Flutter systems engineering.',
        'entries': [
          {
            'id': 'video_1',
            'title': 'Episode 1: State Management at Scale',
            'duration': 1200,
            'url': 'https://www.youtube.com/watch?v=video_1',
          },
          {
            'id': 'video_2',
            'title': 'Episode 2: Android Native Channels & Media3',
            'duration': 1540,
            'url': 'https://www.youtube.com/watch?v=video_2',
          },
          {
            'id': 'video_3',
            'title': 'Episode 3: Clean Architecture & Subsystems',
            'duration': 980,
            'url': 'https://www.youtube.com/watch?v=video_3',
          },
        ]
      };

      final playlist = PlaylistInfo.fromJson(json);

      expect(playlist.id, equals('PL1234567890'));
      expect(playlist.title, equals('Flutter Architecture Deep Dive Series'));
      expect(playlist.itemCount, equals(3));
      expect(playlist.entries.length, equals(3));
      expect(playlist.entries[0].title, equals('Episode 1: State Management at Scale'));
      expect(playlist.entries[1].url, contains('video_2'));
      expect(playlist.entries[2].durationSeconds, equals(980));
    });
  });
}
