import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/settings_screen.dart';
import 'package:meteora/services/native_bridge.dart';
import 'package:meteora/state/download_state.dart';

/// The app asks Android for the panel's highest refresh-rate mode; these tests
/// pin the Dart half of that contract (bridge mapping + the Settings readout).
void main() {
  const channel = MethodChannel('dev.meteora/engine');

  void mockEngine({
    required num activeHz,
    required num maxHz,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getDeviceCapabilities':
          return {
            'displayWidth': 1080,
            'displayHeight': 2400,
            'displayRefreshRate': activeHz,
            'displayMaxRefreshRate': maxHz,
            'supportedVideoCodecs': ['h264', 'vp9'],
            'supportedAudioCodecs': ['aac', 'opus'],
            'freeStorageBytes': 32 * 1024 * 1024 * 1024,
            'isMeteredNetwork': false,
            'batteryLevelPercent': 80,
            'isCharging': false,
          };
        case 'getDownloadLocation':
          return {
            'isCustom': false,
            'displayPath': 'Internal Storage/Download',
            'uri': null,
          };
        default:
          return null;
      }
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('bridge maps the panel maximum separately from the active rate', () async {
    mockEngine(activeHz: 120, maxHz: 120);

    final caps = await NativeBridge.getDeviceCapabilities();

    expect(caps.displayRefreshRate, 120.0);
    expect(caps.displayMaxRefreshRate, 120.0);
    expect(caps.supportsHighRefreshRate, isTrue);
    expect(caps.isRunningAtMaxRefreshRate, isTrue);
  });

  test('bridge falls back to the active rate when the maximum is absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDeviceCapabilities') {
        return {
          'displayWidth': 1080,
          'displayHeight': 2400,
          'displayRefreshRate': 90.0,
          'supportedVideoCodecs': ['h264'],
          'supportedAudioCodecs': ['aac'],
          'freeStorageBytes': 1024,
          'isMeteredNetwork': false,
        };
      }
      return null;
    });

    final caps = await NativeBridge.getDeviceCapabilities();

    expect(caps.displayMaxRefreshRate, 90.0);
    expect(caps.isRunningAtMaxRefreshRate, isTrue);
  });

  testWidgets('Settings reports the active rate against the panel maximum', (tester) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    mockEngine(activeHz: 60, maxHz: 120);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Refresh Rate'), findsOneWidget);
    expect(find.text('60 Hz of 120 Hz'), findsOneWidget);

    db.close();
  });
}
