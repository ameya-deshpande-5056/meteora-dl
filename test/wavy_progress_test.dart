import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/widgets/wavy_progress_indicator.dart';

void main() {
  testWidgets('determinate wave paints without scheduling extra frames', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, child: WavyProgressIndicator(value: 0.42)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(WavyProgressIndicator), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);

    // A determinate indicator must be static, so settling is immediate.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('indeterminate wave animates without settling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, child: WavyProgressIndicator()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(WavyProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falls back to a linear bar when animations are disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: WavyProgressIndicator()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
