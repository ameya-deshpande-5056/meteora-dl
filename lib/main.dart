import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/browser_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/native_bridge.dart';
import 'state/download_state.dart';
import 'state/theme_manager.dart';
import 'widgets/adaptive_scaffold.dart';
import 'widgets/first_launch_setup_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge immersive dark mode styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await DownloadStateManager.instance.init();
  ThemeManager.instance.init(DownloadStateManager.instance.database);

  runApp(const MeteoraDLApp());
}

class MeteoraDLApp extends StatelessWidget {
  const MeteoraDLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return ListenableBuilder(
          listenable: ThemeManager.instance,
          builder: (context, _) {
            return MaterialApp(
              title: 'MeteoraDL',
              debugShowCheckedModeBanner: false,
              theme: ThemeManager.instance.resolveLightTheme(dynamicScheme: lightDynamic),
              darkTheme: ThemeManager.instance.resolveDarkTheme(dynamicScheme: darkDynamic),
              themeMode: ThemeManager.instance.flutterThemeMode,
              home: const MainNavigationScreen(),
            );
          },
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _setupPromptScheduled = false;

  /// URL handed over from the in-app browser; each handoff remounts Home so the
  /// field reflects the newest pick even though the tab keeps its state.
  String? _browserHandoffUrl;
  int _homeHandoffSeq = 0;

  void _sendFromBrowserToHome(String url) {
    setState(() {
      _browserHandoffUrl = url;
      _homeHandoffSeq++;
      _currentIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _listenToDownloadEvents();
    _handleFirstLaunchSetup();
  }

  void _handleFirstLaunchSetup() {
    if (!DownloadStateManager.instance.isFirstLaunchSetupDone) {
      if (_setupPromptScheduled) return;
      _setupPromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FirstLaunchSetupDialog(),
        );
      });
    } else {
      NativeBridge.getPermissionStatus().then((status) {
        if (!status.allGranted) {
          NativeBridge.requestPermissions();
        }
      });
    }
  }

  void _listenToDownloadEvents() {
    NativeBridge.downloadEvents.listen(
      (event) {
        final taskId = event['taskId'] as String? ?? '';
        final statusStr = event['status'] as String? ?? 'downloading';
        final percent = (event['percent'] as num?)?.toDouble() ?? 0.0;
        final speed = event['speed'] as String? ?? '';
        final eta = event['eta'] as String? ?? '';
        final totalSize = event['totalSize'] as String? ?? '';
        final filePath = event['filePath'] as String?;

        TaskStatus status = TaskStatus.downloading;
        if (statusStr == 'completed') {
          status = TaskStatus.completed;
        } else if (statusStr == 'cancelled') {
          status = TaskStatus.cancelled;
        } else if (statusStr == 'error') {
          status = TaskStatus.error;
        } else if (statusStr == 'queued') {
          status = TaskStatus.queued;
        } else if (statusStr == 'paused') {
          status = TaskStatus.paused;
        }

        DownloadStateManager.instance.updateProgress(
          taskId: taskId,
          percent: percent,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          status: status,
          filePath: filePath,
          errorMessage: status == TaskStatus.error && eta.isNotEmpty ? eta : null,
        );
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      currentIndex: _currentIndex,
      onNavigationChanged: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        AdaptiveDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        AdaptiveDestination(
          icon: Icons.downloading_outlined,
          selectedIcon: Icons.downloading_rounded,
          label: 'Downloads',
        ),
        AdaptiveDestination(
          icon: Icons.video_library_outlined,
          selectedIcon: Icons.video_library_rounded,
          label: 'Library',
        ),
        AdaptiveDestination(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Settings',
        ),
        AdaptiveDestination(
          icon: Icons.public_outlined,
          selectedIcon: Icons.public_rounded,
          label: 'Browser',
        ),
      ],
      screens: [
        HomeScreen(
          key: ValueKey('home_$_homeHandoffSeq'),
          initialUrl: _browserHandoffUrl,
          onNavigateToDownloads: () => setState(() => _currentIndex = 1),
        ),
        DownloadsScreen(
          onNavigateToHome: () => setState(() => _currentIndex = 0),
        ),
        const LibraryScreen(),
        const SettingsScreen(),
        BrowserScreen(onSendToHome: _sendFromBrowserToHome),
      ],
    );
  }
}
