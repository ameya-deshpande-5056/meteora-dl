import 'package:meta/meta.dart';

@immutable
class DeviceCapabilities {
  final int displayWidth;
  final int displayHeight;
  final double displayRefreshRate;
  final Set<String> supportedVideoCodecs; // lowercase e.g. {'av1', 'vp9', 'hevc', 'h264', 'avc'}
  final Set<String> supportedAudioCodecs; // lowercase e.g. {'opus', 'aac', 'mp3', 'flac'}
  final int freeStorageBytes;
  final bool isMeteredNetwork;
  final int batteryLevelPercent;
  final bool isCharging;

  const DeviceCapabilities({
    required this.displayWidth,
    required this.displayHeight,
    this.displayRefreshRate = 60.0,
    required this.supportedVideoCodecs,
    required this.supportedAudioCodecs,
    required this.freeStorageBytes,
    required this.isMeteredNetwork,
    this.batteryLevelPercent = 100,
    this.isCharging = true,
  });

  /// Standard modern Android baseline (fallback when native inspection unavailable)
  factory DeviceCapabilities.standardAndroidArm64({
    int freeStorageBytes = 10 * 1024 * 1024 * 1024, // 10 GB
    bool isMeteredNetwork = false,
  }) {
    return DeviceCapabilities(
      displayWidth: 1080,
      displayHeight: 2400,
      displayRefreshRate: 120.0,
      supportedVideoCodecs: {'av1', 'vp9', 'hevc', 'h264', 'avc'},
      supportedAudioCodecs: {'opus', 'aac', 'mp3', 'flac', 'vorbis'},
      freeStorageBytes: freeStorageBytes,
      isMeteredNetwork: isMeteredNetwork,
    );
  }

  bool supportsVideoCodec(String? codec) {
    if (codec == null || codec.isEmpty || codec == 'none') return true;
    final lower = codec.toLowerCase();
    for (final supported in supportedVideoCodecs) {
      if (lower.contains(supported)) return true;
    }
    return false;
  }

  bool supportsAudioCodec(String? codec) {
    if (codec == null || codec.isEmpty || codec == 'none') return true;
    final lower = codec.toLowerCase();
    for (final supported in supportedAudioCodecs) {
      if (lower.contains(supported)) return true;
    }
    return false;
  }
}
