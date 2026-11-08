import 'dart:async';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';

class NativeBridge {
  static const MethodChannel _methodChannel = MethodChannel('dev.meteora/engine');
  static const EventChannel _eventChannel = EventChannel('dev.meteora/downloads');

  static Stream<Map<String, dynamic>>? _downloadEventStream;

  static Stream<Map<String, dynamic>> get downloadEvents {
    _downloadEventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _downloadEventStream!;
  }

  static Future<DeviceCapabilities> getDeviceCapabilities() async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getDeviceCapabilities');
      if (res != null) {
        final videoCodecs = (res['supportedVideoCodecs'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toSet();
        final audioCodecs = (res['supportedAudioCodecs'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toSet();

        return DeviceCapabilities(
          displayWidth: (res['displayWidth'] as num?)?.toInt() ?? 1080,
          displayHeight: (res['displayHeight'] as num?)?.toInt() ?? 2400,
          displayRefreshRate: (res['displayRefreshRate'] as num?)?.toDouble() ?? 60.0,
          supportedVideoCodecs: videoCodecs,
          supportedAudioCodecs: audioCodecs,
          freeStorageBytes: (res['freeStorageBytes'] as num?)?.toInt() ?? (10 * 1024 * 1024 * 1024),
          isMeteredNetwork: res['isMeteredNetwork'] as bool? ?? false,
          batteryLevelPercent: (res['batteryLevelPercent'] as num?)?.toInt() ?? 100,
          isCharging: res['isCharging'] as bool? ?? true,
        );
      }
    } catch (_) {}
    return DeviceCapabilities.standardAndroidArm64();
  }

  static Future<String?> getInitialSharedUrl() async {
    try {
      return await _methodChannel.invokeMethod<String>('getInitialSharedUrl');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> executeExtraction(List<String> command) async {
    return await _methodChannel.invokeMethod<String>('executeExtraction', {
      'command': command,
    });
  }

  static Future<bool> startForegroundDownload({
    required String taskId,
    required String title,
    required List<String> command,
  }) async {
    final res = await _methodChannel.invokeMethod<bool>('startForegroundDownload', {
      'taskId': taskId,
      'title': title,
      'command': command,
    });
    return res ?? false;
  }

  static Future<bool> cancelDownload(String taskId) async {
    final res = await _methodChannel.invokeMethod<bool>('cancelDownload', {
      'taskId': taskId,
    });
    return res ?? false;
  }

  static Future<String?> publishToMediaStore({
    required String filePath,
    required String displayName,
    required String mimeType,
    required bool isVideo,
  }) async {
    return await _methodChannel.invokeMethod<String>('publishToMediaStore', {
      'filePath': filePath,
      'displayName': displayName,
      'mimeType': mimeType,
      'isVideo': isVideo,
    });
  }
}
