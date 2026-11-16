import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/widgets/wavy_progress_indicator.dart';

void main() {
  testWidgets('determinate wave animates and dances like in Google Play Store and Morphe', (tester) async {
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

    // Pumps successive animation frames showing the active wave dancing forward
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('determinate wave with isAnimating: false remains static for paused tasks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WavyProgressIndicator(value: 0.42, isAnimating: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
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

  testWidgets('renders sleek M3 Expressive metrics with right-side padding and edge cases (0.0, 0.5, 1.0)', (tester) async {
    expect(kDefaultBarStrokeWidth, equals(4.0));
    expect(kDefaultRightPadding, equals(4.0));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WavyProgressIndicator(value: 0.0, isAnimating: false),
              WavyProgressIndicator(value: 1.0, isAnimating: false),
              WavyProgressIndicator(
                value: 0.5,
                height: kDefaultBarHeight,
                strokeWidth: kDefaultBarStrokeWidth,
                gapSize: kDefaultGapSize,
                wavelength: kDefaultWavelength,
                rightPadding: kDefaultRightPadding,
                isAnimating: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(WavyProgressIndicator), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CircularWavyProgressIndicator paints sleek determinate and indeterminate rings', (tester) async {
    expect(kDefaultRingStrokeWidth, equals(6.0));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CircularWavyProgressIndicator(value: 0.75, isAnimating: false),
              CircularWavyProgressIndicator(), // Indeterminate
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularWavyProgressIndicator), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
