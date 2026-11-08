import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:meteora/screens/home_screen.dart';
import 'package:meteora/state/download_state.dart';

void main() {
  testWidgets('HomeScreen detects playlist URL and presents batch controls', (WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.meteora/engine'),
      (call) async {
        if (call.method == 'isEngineInstalled') return true;
        if (call.method == 'executeExtraction') {
          return jsonEncode({
            '_type': 'playlist',
            'id': 'PL1234567890',
            'title': 'Flutter Systems & Architecture Masterclass',
            'uploader': 'Meteora Engineering Hub',
            'entries': [
              {
                'id': 'pl_01',
                'title': '01. High Performance Background Concurrency in Kotlin',
                'duration': 1420,
              },
              {
                'id': 'pl_02',
                'title': '02. Zero-Copy FFmpeg Stream Merging & Demuxing',
                'duration': 1180,
              },
              {
                'id': 'pl_03',
                'title': '03. Scoped Storage & MediaStore Android 15 Integration',
                'duration': 960,
              },
              {
                'id': 'pl_04',
                'title': '04. Embedded JavaScript Challenge Solvers with Deno & QuickJS',
                'duration': 1650,
              },
            ],
          });
        }
        return null;
      },
    );

    await DownloadStateManager.instance.init(db: MeteoraDatabase.openInMemory());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(onNavigateToDownloads: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // Enter a playlist URL
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'https://www.youtube.com/playlist?list=PL1234567890');
    await tester.pumpAndSettle();

    // Tap the Inspect & Extract button
    final inspectBtn = find.text('Inspect & Extract');
    expect(inspectBtn, findsOneWidget);
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    // Verify playlist banner appears
    expect(find.text('Detected Playlist'), findsOneWidget);
    expect(find.text('4 VIDEOS'), findsOneWidget);
    expect(find.text('Flutter Systems & Architecture Masterclass'), findsOneWidget);
    expect(find.text('Batch Download (4)'), findsOneWidget);
    expect(find.text('Select Items'), findsOneWidget);

    // Tap Select Items to open playlist bottom sheet
    await tester.tap(find.text('Select Items'));
    await tester.pumpAndSettle();

    expect(find.text('Select Playlist Videos'), findsOneWidget);
    expect(find.text('01. High Performance Background Concurrency in Kotlin'), findsOneWidget);
    expect(find.text('Download 4 Selected'), findsOneWidget);
  });
}
