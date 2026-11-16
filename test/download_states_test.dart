import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/downloads_screen.dart';
import 'package:meteora/screens/library_screen.dart';
import 'package:meteora/state/download_state.dart';

void main() {
  const engineChannel = MethodChannel('dev.meteora/engine');
  final startedCommands = <List<String>>[];

  setUp(() {
    startedCommands.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, (call) async {
          if (call.method == 'startForegroundDownload') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            startedCommands.add(List<String>.from(args['command'] as List));
            return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(engineChannel, null);
  });

  const failedCommand = <String>[
    'yt-dlp',
    '-f',
    '137+140',
    'https://example.com/a',
  ];
  const pausedCommand = <String>[
    'yt-dlp',
    '-f',
    '137+140',
    'https://example.com/b',
  ];

  testWidgets('failed tasks stay visible in the Failed tab', (tester) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);

    DownloadStateManager.instance.addTask(
      DownloadTask(
        taskId: 'failed_task',
        url: 'https://example.com/a',
        title: 'Broken Stream',
        formatLabel: 'Video + Audio',
        status: TaskStatus.error,
        errorMessage: 'HTTP Error 403: Forbidden',
        command: failedCommand,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Failed (1)'), findsOneWidget);
    expect(find.text('Broken Stream'), findsNothing);

    await tester.tap(find.text('Failed (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Broken Stream'), findsOneWidget);
    expect(find.text('HTTP Error 403: Forbidden'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(startedCommands, hasLength(1));
    expect(startedCommands.first, equals(failedCommand));

    await tester.pumpWidget(const SizedBox.shrink());
    db.close();
  });

  testWidgets('interrupted tasks show as resumable instead of disappearing', (
    tester,
  ) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);

    DownloadStateManager.instance.addTask(
      DownloadTask(
        taskId: 'paused_task',
        url: 'https://example.com/b',
        title: 'Half Done Video',
        formatLabel: 'Video + Audio',
        progressPercent: 42.0,
        status: TaskStatus.paused,
        command: pausedCommand,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Half Done Video'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(startedCommands, hasLength(1));
    expect(startedCommands.first, equals(pausedCommand));

    await tester.pumpWidget(const SizedBox.shrink());
    db.close();
  });

  testWidgets('empty download state remains centred despite the tab selector', (
    tester,
  ) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.pumpAndSettle();

    final cardCenter = tester.getCenter(
      find.byKey(const Key('downloads-empty-state')),
    );
    final screenCenter = tester.getCenter(find.byType(MaterialApp));
    expect((cardCenter.dy - screenCenter.dy).abs(), lessThan(24));

    db.close();
  });

  testWidgets('empty library state remains centred despite search filters', (
    tester,
  ) async {
    final db = MeteoraDatabase.openInMemory();
    await DownloadStateManager.instance.init(db: db);
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    final cardCenter = tester.getCenter(
      find.byKey(const Key('library-empty-state')),
    );
    final screenCenter = tester.getCenter(find.byType(MaterialApp));
    expect((cardCenter.dy - screenCenter.dy).abs(), lessThan(24));

    db.close();
  });
}
