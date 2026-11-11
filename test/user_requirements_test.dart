import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/downloads_screen.dart';
import 'package:meteora/screens/home_screen.dart';
import 'package:meteora/screens/library_screen.dart';
import 'package:meteora/screens/settings_screen.dart';
import 'package:meteora/state/download_state.dart';
import 'package:meteora/state/theme_manager.dart';
import 'package:meteora/theme/app_theme.dart';
import 'package:meteora/widgets/liquid_glass_container.dart';
import 'package:meteora/main.dart';

void main() {
  const engineChannel = MethodChannel('dev.meteora/engine');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, null);
  });

  group('Requirement 1: Simple download selector with resolution, bitrate, subtitles & codecs', () {
    testWidgets('lets user pick Video resolution/codec, Audio bitrate/codec, and Subtitle languages', (tester) async {
      final startedCommands = <List<String>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        if (call.method == 'isEngineInstalled') return true;
        if (call.method == 'executeExtraction') {
          return jsonEncode({
            'id': 'vid_123',
            'title': 'Simple Download Test Video',
            'uploader': 'Meteora Channel',
            'formats': [
              {
                'format_id': '137',
                'format_note': '1080p',
                'ext': 'mp4',
                'height': 1080,
                'fps': 30,
                'vcodec': 'avc1.640028',
                'acodec': 'none',
                'vbr': 2400,
                'filesize': 60 * 1024 * 1024,
              },
              {
                'format_id': '247',
                'format_note': '720p',
                'ext': 'webm',
                'height': 720,
                'fps': 60,
                'vcodec': 'vp09.00.31.08',
                'acodec': 'none',
                'vbr': 1400,
                'filesize': 32 * 1024 * 1024,
              },
              {
                'format_id': '251',
                'format_note': 'high',
                'ext': 'webm',
                'vcodec': 'none',
                'acodec': 'opus',
                'abr': 160,
                'filesize': 5 * 1024 * 1024,
              },
              {
                'format_id': '140',
                'format_note': 'medium',
                'ext': 'm4a',
                'vcodec': 'none',
                'acodec': 'mp4a.40.2',
                'abr': 128,
                'filesize': 4 * 1024 * 1024,
              },
            ],
            'subtitles': {
              'en': [
                {'ext': 'vtt', 'name': 'English'},
              ],
            },
            'automatic_captions': {
              'hi': [
                {'ext': 'vtt', 'name': 'Hindi'},
              ],
            },
          });
        }
        if (call.method == 'startForegroundDownload') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          startedCommands.add(List<String>.from(args['command'] as List));
          return true;
        }
        return null;
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(onNavigateToDownloads: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://example.com/watch?v=vid_123');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect & Extract'));
      await tester.pumpAndSettle();

      // Old quality preference UI must be gone
      expect(find.text('Optimal'), findsNothing);
      expect(find.text('Maximum'), findsNothing);

      // Mode chips and stream rows with resolution, bitrate, codec & subtitles are visible
      expect(find.text('Video + Audio'), findsOneWidget);
      expect(find.text('Video Only'), findsOneWidget);
      expect(find.text('Audio Only'), findsOneWidget);
      expect(find.text('Subtitles Only'), findsOneWidget);
      expect(find.text('Video Resolution & Codec'), findsOneWidget);
      expect(find.text('Audio Bitrate & Codec'), findsOneWidget);
      expect(find.text('Subtitles'), findsOneWidget);
      expect(find.text('1080p • H.264 • MP4 (60.0 MB)'), findsOneWidget);
      expect(find.text('160 kbps • Opus • WEBM (5.0 MB)'), findsOneWidget);
      expect(find.text('English (en)'), findsOneWidget);

      // Pick a different video resolution & codec (720p60 VP9)
      await tester.ensureVisible(find.text('Video Resolution & Codec'));
      await tester.tap(find.text('Video Resolution & Codec'));
      await tester.pumpAndSettle();
      final videoBadge = tester.widget<Text>(find.text('720p60'));
      expect(videoBadge.maxLines, equals(1));
      expect(videoBadge.softWrap, isFalse);
      await tester.tap(find.text('VP9 • WEBM'));
      await tester.pumpAndSettle();
      expect(find.text('720p60 • VP9 • WEBM (32.0 MB)'), findsOneWidget);

      // Pick a different audio bitrate & codec (128 kbps AAC)
      await tester.ensureVisible(find.text('Audio Bitrate & Codec'));
      await tester.tap(find.text('Audio Bitrate & Codec'));
      await tester.pumpAndSettle();
      final audioBitrateNum = tester.widget<Text>(find.text('128'));
      expect(audioBitrateNum.overflow, isNull);
      expect(find.text('kbps'), findsWidgets);
      await tester.tap(find.text('AAC • M4A'));
      await tester.pumpAndSettle();
      expect(find.text('128 kbps • AAC • M4A (4.0 MB)'), findsOneWidget);

      // Pick subtitle languages (add Hindi auto-captions)
      await tester.ensureVisible(find.text('Subtitles'));
      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hindi (hi) • Auto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply (2 selected)'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected (en, hi)'), findsOneWidget);

      // Download Video + Audio with chosen streams & subtitles
      await tester.ensureVisible(find.text('Download Video + Audio'));
      await tester.tap(find.text('Download Video + Audio'));
      await tester.pumpAndSettle();
      expect(startedCommands.last, containsAllInOrder(['-f', '247+140']));
      expect(startedCommands.last, contains('--write-subs'));
      expect(startedCommands.last, contains('--write-auto-subs'));
      expect(startedCommands.last, contains('--embed-subs'));
      expect(startedCommands.last, containsAllInOrder(['--sub-langs', 'en,hi']));

      // Switch to Video Only
      await tester.ensureVisible(find.text('Video Only'));
      await tester.tap(find.text('Video Only'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download Video Only'));
      await tester.tap(find.text('Download Video Only'));
      await tester.pumpAndSettle();
      expect(startedCommands.last, containsAllInOrder(['-f', '247']));

      // Switch to Audio Only
      await tester.ensureVisible(find.text('Audio Only'));
      await tester.tap(find.text('Audio Only'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download Audio Only'));
      await tester.tap(find.text('Download Audio Only'));
      await tester.pumpAndSettle();
      expect(startedCommands.last, containsAllInOrder(['-f', '140', '-x']));

      // Switch to Subtitles Only
      await tester.ensureVisible(find.text('Subtitles Only'));
      await tester.tap(find.text('Subtitles Only'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download Subtitles Only'));
      await tester.tap(find.text('Download Subtitles Only'));
      await tester.pumpAndSettle();
      expect(startedCommands.last, contains('--skip-download'));
      expect(startedCommands.last, containsAllInOrder(['--sub-langs', 'en,hi']));

      db.close();
    });

    testWidgets('disables Subtitles Only when no subtitles or captions exist', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        if (call.method == 'isEngineInstalled') return true;
        if (call.method == 'executeExtraction') {
          return jsonEncode({
            'id': 'vid_nosub',
            'title': 'No Subs Video',
            'formats': [
              {
                'format_id': '18',
                'format_note': '360p',
                'ext': 'mp4',
                'height': 360,
                'vcodec': 'avc1',
                'acodec': 'mp4a',
              },
            ],
            'subtitles': {},
            'automatic_captions': {},
          });
        }
        return null;
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(onNavigateToDownloads: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://example.com/watch?v=nosub');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect & Extract'));
      await tester.pumpAndSettle();

      expect(find.text('No subtitles available'), findsOneWidget);
      await tester.ensureVisible(find.text('Subtitles Only'));
      await tester.tap(find.text('Subtitles Only'));
      await tester.pumpAndSettle();

      // Still on Video + Audio because Subtitles Only is disabled
      expect(find.text('Download Video + Audio'), findsOneWidget);

      db.close();
    });
  });

  group('Requirement 2 & 4: Settings download location and improved theme switcher', () {
    testWidgets('displays and updates custom download location and resets to default', (tester) async {
      var currentLocation = <String, dynamic>{
        'isCustom': false,
        'displayPath': 'Internal Storage/Download',
        'uri': null,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        switch (call.method) {
          case 'getDownloadLocation':
            return currentLocation;
          case 'pickDownloadDirectory':
            currentLocation = {
              'isCustom': true,
              'displayPath': 'Internal Storage/Movies/Meteora',
              'uri': 'content://com.android.externalstorage.documents/tree/primary%3AMovies%2FMeteora',
            };
            return currentLocation;
          case 'resetDownloadLocation':
            currentLocation = {
              'isCustom': false,
              'displayPath': 'Internal Storage/Download',
              'uri': null,
            };
            return currentLocation;
          case 'getEngineVersion':
            return '2026.11.08';
          default:
            return null;
        }
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Internal Storage/Download (Default)'), findsOneWidget);
      expect(find.text('Reset to Default Folder'), findsNothing);

      await tester.tap(find.text('Download Location'));
      await tester.pumpAndSettle();

      expect(find.text('Internal Storage/Movies/Meteora'), findsOneWidget);
      expect(find.text('Reset to Default Folder'), findsOneWidget);

      await tester.tap(find.text('Reset to Default Folder'));
      await tester.pumpAndSettle();

      expect(find.text('Internal Storage/Download (Default)'), findsOneWidget);
      expect(find.text('Reset to Default Folder'), findsNothing);

      db.close();
    });

    test('ThemeManager persists and restores selected theme in SQLite', () {
      final db = MeteoraDatabase.openInMemory();
      ThemeManager.instance.init(db);
      ThemeManager.instance.setThemeMode(AppThemeMode.dark);
      expect(db.getSetting('theme_mode'), equals('dark'));

      ThemeManager.instance.setThemeMode(AppThemeMode.light);
      expect(db.getSetting('theme_mode'), equals('light'));

      // Reset to system and reload from DB holding 'light'
      ThemeManager.instance.init(db);
      expect(ThemeManager.instance.currentMode, equals(AppThemeMode.light));

      ThemeManager.instance.setThemeMode(AppThemeMode.system);
      db.close();
    });
  });

  group('Requirement 3: External player integration (no bundled Media3)', () {
    testWidgets('LibraryScreen opens external player instead of bundled Media3 UI', (tester) async {
      final playCalls = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        if (call.method == 'playMedia') {
          playCalls.add(Map<String, dynamic>.from(call.arguments as Map));
          return true;
        }
        return null;
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);

      DownloadStateManager.instance.addTask(
        DownloadTask(
          taskId: 't_vid',
          url: 'https://example.com/v',
          title: 'Awesome Documentary',
          formatLabel: 'Video + Audio',
          status: TaskStatus.downloading,
          createdAt: DateTime.now(),
        ),
      );
      DownloadStateManager.instance.updateProgress(
        taskId: 't_vid',
        percent: 100.0,
        speed: '0 B/s',
        eta: 'Done',
        totalSize: '42.0 MB',
        status: TaskStatus.completed,
        filePath: 'content://media/external_primary/downloads/99',
      );

      // Subtitles-only completed tasks should remain in Downloads, not pollute video/audio Library
      DownloadStateManager.instance.addTask(
        DownloadTask(
          taskId: 't_sub',
          url: 'https://example.com/s',
          title: 'Only Subtitles',
          formatLabel: 'Subtitles Only',
          status: TaskStatus.downloading,
          createdAt: DateTime.now(),
        ),
      );
      DownloadStateManager.instance.updateProgress(
        taskId: 't_sub',
        percent: 100.0,
        speed: '0 B/s',
        eta: 'Done',
        totalSize: '12 KB',
        status: TaskStatus.completed,
        filePath: 'content://media/external_primary/downloads/100',
      );

      expect(DownloadStateManager.instance.libraryItems.length, equals(1));
      expect(
        DownloadStateManager.instance.libraryItems.first.mediaType,
        equals(LibraryMediaType.video),
      );
      expect(
        DownloadStateManager.instance.libraryItems.first.localFilePath,
        equals('content://media/external_primary/downloads/99'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awesome Documentary'), findsOneWidget);
      expect(find.text('Only Subtitles'), findsNothing);

      // Open modal sheet for item
      await tester.tap(find.text('Awesome Documentary'));
      await tester.pumpAndSettle();

      // Media3 UI must be completely gone
      expect(find.textContaining('Media3'), findsNothing);
      expect(find.textContaining('ExoPlayer'), findsNothing);
      expect(find.text('Open in External Player'), findsOneWidget);

      await tester.tap(find.text('Open in External Player'));
      await tester.pumpAndSettle();

      expect(playCalls.length, equals(1));
      expect(playCalls.first['filePath'], equals('content://media/external_primary/downloads/99'));
      expect(playCalls.first['title'], equals('Awesome Documentary'));
      expect(playCalls.first['isVideo'], isTrue);

      db.close();
    });

    testWidgets('DownloadsScreen opens completed file in external player', (tester) async {
      final playCalls = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        if (call.method == 'playMedia') {
          playCalls.add(Map<String, dynamic>.from(call.arguments as Map));
          return true;
        }
        return null;
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);

      DownloadStateManager.instance.addTask(
        DownloadTask(
          taskId: 't_aud',
          url: 'https://example.com/a',
          title: 'Synthwave Mix',
          formatLabel: 'Audio Only',
          status: TaskStatus.downloading,
          createdAt: DateTime.now(),
        ),
      );
      DownloadStateManager.instance.updateProgress(
        taskId: 't_aud',
        percent: 100.0,
        speed: '0 B/s',
        eta: 'Done',
        totalSize: '8.4 MB',
        status: TaskStatus.completed,
        filePath: 'content://media/external_primary/downloads/101',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DownloadsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Synthwave Mix'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.open_in_new_rounded));
      await tester.pumpAndSettle();

      expect(playCalls.length, equals(1));
      expect(playCalls.first['filePath'], equals('content://media/external_primary/downloads/101'));
      expect(playCalls.first['isVideo'], isFalse);

      db.close();
    });
  });

  group('Requirement 5: Liquid Glass theming across app surfaces', () {
    testWidgets('renders LiquidGlassAppBar, LiquidGlassBackground, BackdropFilter, and floating nav bar', (tester) async {
      final db = MeteoraDatabase.openInMemory();
      db.setSetting('first_launch_setup_done', 'true');
      await DownloadStateManager.instance.init(db: db);
      ThemeManager.instance.init(db);

      await tester.pumpWidget(const MeteoraDLApp());
      await tester.pumpAndSettle();

      // Home screen renders LiquidGlassAppBar, LiquidGlassBackground, floating nav bar, URL bar, and BackdropFilter
      expect(find.byType(LiquidGlassAppBar), findsWidgets);
      expect(find.byType(LiquidGlassBackground), findsWidgets);
      expect(find.byType(LiquidGlassContainer), findsWidgets);
      expect(find.byType(BackdropFilter), findsWidgets);

      // Navigate to Library and verify glass SearchBar wrapper
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);

      // Navigate to Settings and verify glass theme picker dialog
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Choose theme'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      db.close();
    });
  });

  group('Requirement 6: First-launch storage & permissions setup', () {
    testWidgets('prompts for download folder and permissions on first launch and skips on subsequent launches', (tester) async {
      var requestPermissionsCalls = 0;
      var pickDirectoryCalls = 0;
      var location = <String, dynamic>{
        'isCustom': false,
        'displayPath': 'Internal Storage/Download',
        'uri': null,
      };
      var permStatus = <String, dynamic>{
        'notificationsGranted': false,
        'storageGranted': false,
        'allGranted': false,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (call) async {
        switch (call.method) {
          case 'getPermissionStatus':
            return permStatus;
          case 'requestPermissions':
            requestPermissionsCalls++;
            permStatus = {
              'notificationsGranted': true,
              'storageGranted': true,
              'allGranted': true,
            };
            return permStatus;
          case 'getDownloadLocation':
            return location;
          case 'pickDownloadDirectory':
            pickDirectoryCalls++;
            location = {
              'isCustom': true,
              'displayPath': 'Internal Storage/Movies/Meteora',
              'uri': 'content://com.android.externalstorage.documents/tree/primary%3AMovies%2FMeteora',
            };
            return location;
          case 'getEngineVersion':
            return '2026.11.08';
          default:
            return null;
        }
      });

      final db = MeteoraDatabase.openInMemory();
      await DownloadStateManager.instance.init(db: db);
      ThemeManager.instance.init(db);

      await tester.pumpWidget(const MeteoraDLApp());
      await tester.pumpAndSettle();

      // Onboarding modal appears automatically on first launch
      expect(find.text('Welcome to MeteoraDL'), findsOneWidget);
      expect(find.text('Internal Storage/Download (Default public folder)'), findsOneWidget);
      expect(find.text('Grant All Permissions'), findsOneWidget);
      expect(find.text('Allow Permissions & Continue'), findsOneWidget);

      // User picks custom folder
      await tester.tap(find.text('Choose Folder'));
      await tester.pumpAndSettle();
      expect(pickDirectoryCalls, equals(1));
      expect(find.text('Internal Storage/Movies/Meteora'), findsOneWidget);

      // User grants all permissions
      await tester.tap(find.text('Grant All Permissions'));
      await tester.pumpAndSettle();
      expect(requestPermissionsCalls, equals(1));
      expect(find.text('Granted'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Complete setup
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to MeteoraDL'), findsNothing);
      expect(DownloadStateManager.instance.isFirstLaunchSetupDone, isTrue);

      // Settings reflects the chosen download folder immediately
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Internal Storage/Movies/Meteora'), findsOneWidget);

      // Subsequent launch with same DB does NOT show setup dialog again
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await DownloadStateManager.instance.init(db: db);
      await tester.pumpWidget(const MeteoraDLApp());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to MeteoraDL'), findsNothing);

      db.close();
    });
  });
}
