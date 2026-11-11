import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/main.dart';
import 'package:meteora/state/download_state.dart';
import 'package:meteora/state/theme_manager.dart';
import 'package:meteora/theme/app_theme.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.meteora/engine'), null);
  });

  testWidgets('MeteoraDL app smoke and navigation test', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.meteora/engine'), (call) async {
      if (call.method == 'getPermissionStatus') {
        return {'notificationsGranted': false, 'storageGranted': false, 'allGranted': false};
      }
      if (call.method == 'requestPermissions') {
        return {'notificationsGranted': true, 'storageGranted': true, 'allGranted': true};
      }
      if (call.method == 'getDownloadLocation') {
        return {'isCustom': false, 'displayPath': 'Internal Storage/Download', 'uri': null};
      }
      return null;
    });

    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    ThemeManager.instance.init(db);

    await tester.pumpWidget(const MeteoraDLApp());
    await tester.pumpAndSettle();

    // First-launch setup dialog appears on fresh install
    expect(find.text('Welcome to MeteoraDL'), findsOneWidget);
    await tester.ensureVisible(find.text('Allow Permissions & Continue'));
    await tester.tap(find.text('Allow Permissions & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MeteoraDL'), findsNothing);

    // Verify MeteoraDL brand title is displayed
    expect(find.text('MeteoraDL'), findsOneWidget);

    // Verify all 4 navigation destinations exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap Downloads tab
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Active (0)'), findsOneWidget);

    // Tap Library tab
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Media Library'), findsOneWidget);

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Download Location'), findsOneWidget);
    expect(find.text('Package Update Manager'), findsOneWidget);
    expect(find.text('JavaScript Challenge Solver'), findsOneWidget);
    expect(find.text('Hardware Diagnostics'), findsOneWidget);

    // Open Theme picker dialog and select AMOLED Black
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.text('Choose theme'), findsOneWidget);

    await tester.tap(find.text('AMOLED Black'));
    await tester.pumpAndSettle();
    expect(ThemeManager.instance.currentMode, equals(AppThemeMode.amoled));
    expect(find.text('AMOLED Black'), findsOneWidget);

    db.close();
  });
}
