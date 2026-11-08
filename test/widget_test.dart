import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/main.dart';

void main() {
  testWidgets('MeteoraDL app smoke and navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(const MeteoraDLApp());
    await tester.pumpAndSettle();

    // Verify METEORADL brand title is displayed
    expect(find.text('METEORADL'), findsOneWidget);

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
    expect(find.text('PACKAGE UPDATE MANAGER'), findsOneWidget);
    expect(find.text('JAVASCRIPT CHALLENGE SOLVER'), findsOneWidget);
    expect(find.text('HARDWARE CODEC DIAGNOSTICS'), findsOneWidget);
  });
}
