import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/native_bridge.dart';
import 'state/download_state.dart';
import 'state/theme_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/adaptive_scaffold.dart';

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

  runApp(const MeteoraDLApp());
}

class MeteoraDLApp extends StatelessWidget {
  const MeteoraDLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MeteoraDL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: ThemeManager.instance.activeDarkTheme,
          themeMode: ThemeManager.instance.flutterThemeMode,
          home: const MainNavigationScreen(),
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

  @override
  void initState() {
    super.initState();
    _listenToDownloadEvents();
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

        TaskStatus status = TaskStatus.downloading;
        if (statusStr == 'completed') {
          status = TaskStatus.completed;
        } else if (statusStr == 'cancelled') {
          status = TaskStatus.cancelled;
        } else if (statusStr == 'error') {
          status = TaskStatus.error;
        }

        DownloadStateManager.instance.updateProgress(
          taskId: taskId,
          percent: percent,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          status: status,
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
      ],
      screens: [
        HomeScreen(
          onNavigateToDownloads: () => setState(() => _currentIndex = 1),
        ),
        DownloadsScreen(
          onNavigateToHome: () => setState(() => _currentIndex = 0),
        ),
        const LibraryScreen(),
        const SettingsScreen(),
      ],
    );
  }
}
