import 'package:test/test.dart';
import 'package:media_engine/media_engine.dart';

void main() {
  group('DeviceCapabilities refresh rate', () {
    test('treats 60 Hz panels as non-high-refresh', () {
      final caps = DeviceCapabilities(
        displayWidth: 1080,
        displayHeight: 2400,
        displayRefreshRate: 60.0,
        displayMaxRefreshRate: 60.0,
        supportedVideoCodecs: const {'h264'},
        supportedAudioCodecs: const {'aac'},
        freeStorageBytes: 1024,
        isMeteredNetwork: false,
      );

      expect(caps.supportsHighRefreshRate, isFalse);
      expect(caps.isRunningAtMaxRefreshRate, isTrue);
    });

    test('reports a high refresh panel and whether the window reached its max', () {
      DeviceCapabilities caps(double active) => DeviceCapabilities(
            displayWidth: 1080,
            displayHeight: 2400,
            displayRefreshRate: active,
            displayMaxRefreshRate: 120.0,
            supportedVideoCodecs: const {'h264'},
            supportedAudioCodecs: const {'aac'},
            freeStorageBytes: 1024,
            isMeteredNetwork: false,
          );

      expect(caps(120.0).supportsHighRefreshRate, isTrue);
      expect(caps(120.0).isRunningAtMaxRefreshRate, isTrue);
      expect(caps(60.0).isRunningAtMaxRefreshRate, isFalse);
    });

    test('the fallback baseline advertises the panel maximum', () {
      final fallback = DeviceCapabilities.standardAndroidArm64();
      expect(fallback.displayMaxRefreshRate, 120.0);
      expect(fallback.supportsHighRefreshRate, isTrue);
    });
  });
}
