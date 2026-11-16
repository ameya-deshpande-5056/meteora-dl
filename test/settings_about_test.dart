import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/settings_screen.dart';
import 'package:meteora/services/app_update_service.dart';
import 'package:meteora/state/download_state.dart';
import 'package:meteora/state/theme_manager.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.meteora/engine'), (call) async {
      if (call.method == 'getDeviceCapabilities') {
        return {
          'displayWidth': 1080,
          'displayHeight': 2400,
          'displayRefreshRate': 120.0,
          'displayMaxRefreshRate': 120.0,
          'supportedVideoCodecs': ['av1', 'vp9', 'hevc', 'h264'],
          'supportedAudioCodecs': ['opus', 'aac', 'mp3', 'flac'],
          'freeStorageBytes': 10 * 1024 * 1024 * 1024,
        };
      }
      if (call.method == 'getEngineVersion') {
        return '2026.11.16';
      }
      if (call.method == 'getJsRuntimeStatus') {
        return {'available': true, 'name': 'quickjs', 'version': '2025-04-26'};
      }
      if (call.method == 'getDownloadLocation') {
        return {'isCustom': false, 'displayPath': 'Internal Storage/Download', 'uri': null};
      }
      if (call.method == 'openUrl') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.meteora/engine'), null);
  });

  testWidgets('Settings renders About App, version badge, and Check for Updates', (tester) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    ThemeManager.instance.init(db);

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to bottom of SettingsScreen
    final aboutHeader = find.text('About App');
    await tester.scrollUntilVisible(aboutHeader, 300);
    expect(aboutHeader, findsOneWidget);

    // Verify Meteora title and current version badge
    expect(find.text('Meteora'), findsAtLeastNWidgets(1));
    expect(find.text('v${AppUpdateService.currentVersion}'), findsOneWidget);
    expect(find.text('Check for Updates'), findsOneWidget);

    // Verify About Meteora, GitHub Repository, and Open Source Licenses tiles exist
    final aboutTile = find.text('About Meteora');
    await tester.scrollUntilVisible(aboutTile, 200);
    expect(aboutTile, findsOneWidget);

    final githubTile = find.text('GitHub Repository');
    await tester.scrollUntilVisible(githubTile, 200);
    expect(githubTile, findsOneWidget);

    final licensesTile = find.text('Open Source Licenses');
    await tester.scrollUntilVisible(licensesTile, 200);
    expect(licensesTile, findsOneWidget);

    // Tap About Meteora to open the dialog
    await tester.tap(aboutTile);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Version ${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuildNumber})'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('JS Solver'), findsOneWidget);
    expect(find.text('Muxer'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);

    db.close();
  });
}
