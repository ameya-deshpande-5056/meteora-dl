import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/main.dart';

void main() {
  testWidgets('MeteoraDL app smoke and navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(const MeteoraDLApp());
    await tester.pumpAndSettle();

    // Verify MeteoraDL brand title is displayed
    expect(find.text('MeteoraDL'), findsOneWidget);

    // Verify all 4 navigation destinations exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap Downloads tab
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Active (0)'), findsOneWidget);

    // Tap Library tab
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Media Library'), findsOneWidget);

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Package Update Manager'), findsOneWidget);
    expect(find.text('JavaScript Challenge Solver'), findsOneWidget);
    expect(find.text('Hardware Diagnostics'), findsOneWidget);

    // Tap AMOLED theme button
    await tester.tap(find.text('AMOLED'));
    await tester.pumpAndSettle();
  });
}
