import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/native_bridge.dart';
import 'state/download_state.dart';
import 'theme/liquid_glass_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge immersive dark mode styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: LiquidGlassTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MeteoraApp());
}

class MeteoraApp extends StatelessWidget {
  const MeteoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meteora',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.themeData,
      home: const MainNavigationScreen(),
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onNavigateToDownloads: () => setState(() => _currentIndex = 1),
          ),
          const DownloadsScreen(),
          const LibraryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.downloading_outlined),
            selectedIcon: Icon(Icons.downloading_rounded),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
