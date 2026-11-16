import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/settings_screen.dart';
import 'package:meteora/state/download_state.dart';

void main() {
  const engineChannel = MethodChannel('dev.meteora/engine');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, null);
  });

  testWidgets('Settings reports the bundled EJS runtime when available', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, (call) async {
          switch (call.method) {
            case 'getDownloadLocation':
              return {
                'isCustom': false,
                'displayPath': 'Internal Storage/Download',
                'uri': null,
              };
            case 'getEngineVersion':
              return '2026.11.12';
            case 'getJsRuntimeStatus':
              return {
                'available': true,
                'name': 'quickjs',
                'path': '/data/app/base.apk!/lib/arm64-v8a/libqjs.so',
                'version': 'QuickJS version 2025-04-26',
              };
            default:
              return null;
          }
        });

    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('JavaScript Challenge Solver'), findsOneWidget);
    expect(find.text('QuickJS (bundled)'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('QuickJS version 2025-04-26'), findsOneWidget);

    db.close();
  });

  testWidgets('Settings warns when no EJS runtime could be resolved', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, (call) async {
          switch (call.method) {
            case 'getDownloadLocation':
              return {
                'isCustom': false,
                'displayPath': 'Internal Storage/Download',
                'uri': null,
              };
            case 'getJsRuntimeStatus':
              return {
                'available': false,
                'name': null,
                'path': null,
                'version': null,
              };
            default:
              return null;
          }
        });

    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No JavaScript runtime'), findsOneWidget);
    expect(find.text('MISSING'), findsOneWidget);

    db.close();
  });

  testWidgets('Settings can refresh the cached EJS component', (tester) async {
    var didRefresh = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, (call) async {
          switch (call.method) {
            case 'getDownloadLocation':
              return {
                'isCustom': false,
                'displayPath': 'Internal Storage/Download',
                'uri': null,
              };
            case 'getJsRuntimeStatus':
              return {
                'available': true,
                'name': 'quickjs',
                'version': 'QuickJS',
                'path': '/app/qjs',
              };
            case 'refreshEjsComponents':
              didRefresh = true;
              return true;
            default:
              return null;
          }
        });

    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Refresh EJS Components'));
    await tester.tap(find.text('Refresh EJS Components'));
    await tester.pumpAndSettle();

    expect(didRefresh, isTrue);
    expect(
      find.text(
        'EJS will be refreshed from the official channel on the next extraction or download.',
      ),
      findsOneWidget,
    );
    db.close();
  });
}
