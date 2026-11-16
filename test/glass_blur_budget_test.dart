import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/downloads_screen.dart';
import 'package:meteora/screens/home_screen.dart';
import 'package:meteora/screens/library_screen.dart';
import 'package:meteora/screens/settings_screen.dart';
import 'package:meteora/state/download_state.dart';
import 'package:meteora/widgets/adaptive_scaffold.dart';

/// Each `BackdropFilter` is a full saveLayer + blur pass. Content cards must not
/// add one: a screen may only pay for its own app bar, and the dock pays for
/// itself once. This guards against re-introducing a blur per card.
void main() {
  const engineChannel = MethodChannel('dev.meteora/engine');

  setUp(() {
    // Phone-sized surface: the adaptive shell only shows the dock (and not the
    // desktop rail) below its tablet breakpoint.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, (call) async {
      switch (call.method) {
        case 'getPermissionStatus':
        case 'requestPermissions':
          return {
            'notificationsGranted': true,
            'storageGranted': true,
            'allGranted': true,
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, null);
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
    expect(
      find.byType(BackdropFilter),
      findsOneWidget,
      reason: 'Only the app bar may blur; content cards must stay blur-free',
    );
  }

  testWidgets('each screen pays for exactly one blur (its app bar)', (tester) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);

    await pumpScreen(tester, HomeScreen(onNavigateToDownloads: () {}));
    await pumpScreen(tester, const DownloadsScreen());
    await pumpScreen(tester, const LibraryScreen());
    await pumpScreen(tester, const SettingsScreen());

    db.close();
  });

  testWidgets('the floating dock costs one blur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          currentIndex: 0,
          onNavigationChanged: (_) {},
          destinations: const [
            AdaptiveDestination(icon: Icons.home, selectedIcon: Icons.home, label: 'Home'),
            AdaptiveDestination(icon: Icons.settings, selectedIcon: Icons.settings, label: 'Settings'),
          ],
          screens: const [SizedBox.expand(), SizedBox.expand()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
