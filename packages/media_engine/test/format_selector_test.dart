import 'package:media_engine/media_engine.dart';
import 'package:test/test.dart';

void main() {
  group('IntelligentFormatSelector', () {
    late DeviceCapabilities standardDevice;
    late DeviceCapabilities meteredDevice;
    late DeviceCapabilities lowStorageDevice;

    setUp(() {
      standardDevice = DeviceCapabilities.standardAndroidArm64(
        freeStorageBytes: 50 * 1024 * 1024 * 1024, // 50 GB
        isMeteredNetwork: false,
      );

      meteredDevice = DeviceCapabilities.standardAndroidArm64(
        freeStorageBytes: 50 * 1024 * 1024 * 1024,
        isMeteredNetwork: true,
      );

      lowStorageDevice = DeviceCapabilities.standardAndroidArm64(
        freeStorageBytes: 200 * 1024 * 1024, // 200 MB
        isMeteredNetwork: false,
      );
    });

    test('selects optimal 1080p stream for standard device on unmetered Wi-Fi', () {
      final media = MediaInfo(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up',
        durationSeconds: 212,
        formats: [
          const FormatInfo(
            formatId: '137',
            formatNote: '1080p',
            ext: 'mp4',
            height: 1080,
            fps: 30,
            vcodec: 'avc1.640028',
            filesize: 60 * 1024 * 1024,
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: '313',
            formatNote: '2160p (4K)',
            ext: 'webm',
            height: 2160,
            fps: 30,
            vcodec: 'vp9',
            filesize: 350 * 1024 * 1024,
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: '140',
            formatNote: 'medium',
            ext: 'm4a',
            acodec: 'mp4a.40.2',
            abr: 128,
            filesize: 4 * 1024 * 1024,
            streamType: StreamType.audioOnly,
          ),
          const FormatInfo(
            formatId: '251',
            formatNote: 'high',
            ext: 'webm',
            acodec: 'opus',
            abr: 160,
            filesize: 5 * 1024 * 1024,
            streamType: StreamType.audioOnly,
          ),
        ],
      );

      const selector = IntelligentFormatSelector();
      final rec = selector.recommendFormat(media: media, device: standardDevice);

      expect(rec.videoFormat, isNotNull);
      expect(rec.audioFormat, isNotNull);
      expect(rec.directStreamCopyPossible, isTrue);
      expect(rec.ytdlpFormatSelector, contains('+'));
    });

    test('caps resolution on metered mobile data to conserve bandwidth', () {
      final media = MediaInfo(
        id: 'test_vid',
        title: 'High Resolution Video',
        formats: [
          const FormatInfo(
            formatId: '720p_avc',
            formatNote: '720p',
            ext: 'mp4',
            height: 720,
            vcodec: 'avc1',
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: '1080p_av1',
            formatNote: '1080p',
            ext: 'mp4',
            height: 1080,
            vcodec: 'av01',
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: '4k_vp9',
            formatNote: '2160p',
            ext: 'webm',
            height: 2160,
            vcodec: 'vp9',
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: 'audio_opus',
            formatNote: 'audio',
            ext: 'opus',
            acodec: 'opus',
            abr: 128,
            streamType: StreamType.audioOnly,
          ),
        ],
      );

      const selector = IntelligentFormatSelector();
      final rec = selector.recommendFormat(media: media, device: meteredDevice);

      expect(rec.videoFormat?.height, lessThanOrEqualTo(1080));
    });

    test('audio-only preference returns dedicated audio stream', () {
      final media = MediaInfo(
        id: 'music_track',
        title: 'Lossless Audio Sample',
        formats: [
          const FormatInfo(
            formatId: '1080p_vid',
            formatNote: '1080p',
            ext: 'mp4',
            height: 1080,
            vcodec: 'avc1',
            streamType: StreamType.videoOnly,
          ),
          const FormatInfo(
            formatId: 'audio_opus_high',
            formatNote: 'high audio',
            ext: 'opus',
            acodec: 'opus',
            abr: 160,
            streamType: StreamType.audioOnly,
          ),
        ],
      );

      const selector = IntelligentFormatSelector(preference: QualityPreference.audioOnly);
      final rec = selector.recommendFormat(media: media, device: standardDevice);

      expect(rec.videoFormat, isNull);
      expect(rec.audioFormat?.formatId, equals('audio_opus_high'));
      expect(rec.requiresMuxing, isFalse);
    });
  });
}
