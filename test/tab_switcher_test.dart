import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/theme/app_motion.dart';
import 'package:meteora/widgets/adaptive_scaffold.dart';

/// The phone dock draws one sliding glass indicator instead of per-tab
/// capsules, so the selected pill physically travels between destinations.
void main() {
  const destinations = [
    AdaptiveDestination(icon: Icons.home, selectedIcon: Icons.home, label: 'Home'),
    AdaptiveDestination(
      icon: Icons.downloading,
      selectedIcon: Icons.downloading,
      label: 'Downloads',
    ),
    AdaptiveDestination(
      icon: Icons.settings,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  Future<void> pumpDock(
    WidgetTester tester, {
    required int index,
    required ValueChanged<int> onChanged,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: AdaptiveScaffold(
            currentIndex: index,
            onNavigationChanged: onChanged,
            destinations: destinations,
            screens: const [
              SizedBox.expand(),
              SizedBox.expand(),
              SizedBox.expand(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double indicatorLeft(WidgetTester tester) {
    final positioned = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned).first,
    );
    return positioned.left!;
  }

  testWidgets('the indicator sits under the selected destination', (tester) async {
    await pumpDock(tester, index: 0, onChanged: (_) {});
    final atFirst = indicatorLeft(tester);

    await pumpDock(tester, index: 2, onChanged: (_) {});
    final atThird = indicatorLeft(tester);

    expect(atFirst, 0.0);
    expect(atThird, greaterThan(atFirst));
  });

  testWidgets('tapping a destination reports the index', (tester) async {
    int? tapped;
    await pumpDock(tester, index: 0, onChanged: (i) => tapped = i);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('reduced motion snaps the indicator without a transition', (tester) async {
    await pumpDock(tester, index: 1, onChanged: (_) {}, reduceMotion: true);

    final positioned = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned).first,
    );
    expect(positioned.duration, Duration.zero);
    expect(positioned.curve, AppMotion.spring);
  });

  testWidgets('selecting the active destination is a no-op', (tester) async {
    var calls = 0;
    await pumpDock(tester, index: 0, onChanged: (_) => calls++);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });
}
