import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';

@immutable
class DownloadLocationInfo {
  final bool isCustom;
  final String displayPath;
  final String? uri;

  const DownloadLocationInfo({
    required this.isCustom,
    required this.displayPath,
    this.uri,
  });

  factory DownloadLocationInfo.defaultLocation() => const DownloadLocationInfo(
        isCustom: false,
        displayPath: 'Internal Storage/Download',
      );

  factory DownloadLocationInfo.fromMap(Map<dynamic, dynamic> map) {
    return DownloadLocationInfo(
      isCustom: map['isCustom'] as bool? ?? false,
      displayPath: (map['displayPath'] as String?)?.trim().isNotEmpty == true
          ? map['displayPath'] as String
          : 'Internal Storage/Download',
      uri: map['uri'] as String?,
    );
  }
}

@immutable
class PermissionStatusInfo {
  final bool notificationsGranted;
  final bool storageGranted;
  final bool allGranted;

  const PermissionStatusInfo({
    required this.notificationsGranted,
    required this.storageGranted,
    required this.allGranted,
  });

  factory PermissionStatusInfo.unknown() => const PermissionStatusInfo(
        notificationsGranted: false,
        storageGranted: false,
        allGranted: false,
      );

  factory PermissionStatusInfo.fromMap(Map<dynamic, dynamic> map) {
    return PermissionStatusInfo(
      notificationsGranted: map['notificationsGranted'] as bool? ?? false,
      storageGranted: map['storageGranted'] as bool? ?? false,
      allGranted: map['allGranted'] as bool? ?? false,
    );
  }
}

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

  static Future<bool> isEngineInstalled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isEngineInstalled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getEngineVersion() async {
    try {
      return await _methodChannel.invokeMethod<String>('getEngineVersion');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> updateEngine() async {
    try {
      return await _methodChannel.invokeMethod<String>('updateEngine');
    } catch (_) {
      return null;
    }
  }

  static Future<PermissionStatusInfo> getPermissionStatus() async {
    try {
      final res = await _methodChannel.invokeMethod<dynamic>('getPermissionStatus');
      if (res is Map) {
        return PermissionStatusInfo.fromMap(res);
      }
    } catch (_) {}
    return PermissionStatusInfo.unknown();
  }

  static Future<PermissionStatusInfo> requestPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<dynamic>('requestPermissions');
      if (res is Map) {
        return PermissionStatusInfo.fromMap(res);
      }
      if (res == true) {
        return const PermissionStatusInfo(
          notificationsGranted: true,
          storageGranted: true,
          allGranted: true,
        );
      }
    } catch (_) {}
    return PermissionStatusInfo.unknown();
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

  static Future<DownloadLocationInfo> getDownloadLocation() async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getDownloadLocation');
      if (res != null) {
        return DownloadLocationInfo.fromMap(res);
      }
    } catch (_) {}
    return DownloadLocationInfo.defaultLocation();
  }

  static Future<DownloadLocationInfo?> pickDownloadDirectory() async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('pickDownloadDirectory');
      if (res != null) {
        return DownloadLocationInfo.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  static Future<DownloadLocationInfo> resetDownloadLocation() async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('resetDownloadLocation');
      if (res != null) {
        return DownloadLocationInfo.fromMap(res);
      }
    } catch (_) {}
    return DownloadLocationInfo.defaultLocation();
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

  /// Opens [filePath] in an external player such as VLC or mpv via Android's ACTION_VIEW chooser.
  static Future<bool> openInExternalPlayer({
    required String filePath,
    required String title,
    bool isVideo = true,
    String? mimeType,
  }) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('playMedia', {
        'filePath': filePath,
        'title': title,
        'isVideo': isVideo,
        if (mimeType != null) 'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
