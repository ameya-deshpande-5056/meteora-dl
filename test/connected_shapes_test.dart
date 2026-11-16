import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/theme/app_shapes.dart';
import 'package:meteora/theme/app_typography.dart';
import 'package:meteora/widgets/settings_group.dart';

void main() {
  group('ConnectedShapes Geometry & Radii (Morphe Architecture)', () {
    test('ConnectedShapes.card inColumn calculates correct border radii', () {
      const shapes = ConnectedShapes.card;

      // 1 item: rounded on all corners (20dp)
      final single = shapes.inColumn(0, 1).borderRadius as BorderRadius;
      expect(single.topLeft.x, equals(AppShapes.cornerLargeIncreased));
      expect(single.topRight.x, equals(AppShapes.cornerLargeIncreased));
      expect(single.bottomLeft.x, equals(AppShapes.cornerLargeIncreased));
      expect(single.bottomRight.x, equals(AppShapes.cornerLargeIncreased));

      // 3 items: top, middle, bottom
      final top = shapes.inColumn(0, 3).borderRadius as BorderRadius;
      expect(top.topLeft.x, equals(AppShapes.cornerLargeIncreased));
      expect(top.topRight.x, equals(AppShapes.cornerLargeIncreased));
      expect(top.bottomLeft.x, equals(AppShapes.innerCorner)); // 4dp
      expect(top.bottomRight.x, equals(AppShapes.innerCorner));

      final middle = shapes.inColumn(1, 3).borderRadius as BorderRadius;
      expect(middle.topLeft.x, equals(AppShapes.innerCorner));
      expect(middle.topRight.x, equals(AppShapes.innerCorner));
      expect(middle.bottomLeft.x, equals(AppShapes.innerCorner));
      expect(middle.bottomRight.x, equals(AppShapes.innerCorner));

      final bottom = shapes.inColumn(2, 3).borderRadius as BorderRadius;
      expect(bottom.topLeft.x, equals(AppShapes.innerCorner));
      expect(bottom.topRight.x, equals(AppShapes.innerCorner));
      expect(bottom.bottomLeft.x, equals(AppShapes.cornerLargeIncreased));
      expect(bottom.bottomRight.x, equals(AppShapes.cornerLargeIncreased));
    });

    test('ConnectedShapes.pill inRow calculates correct border radii', () {
      const shapes = ConnectedShapes.pill;

      final leading = shapes.inRow(0, 3).borderRadius as BorderRadius;
      expect(leading.topLeft.x, equals(AppShapes.full));
      expect(leading.bottomLeft.x, equals(AppShapes.full));
      expect(leading.topRight.x, equals(AppShapes.innerCorner));
      expect(leading.bottomRight.x, equals(AppShapes.innerCorner));

      final middle = shapes.inRow(1, 3).borderRadius as BorderRadius;
      expect(middle.topLeft.x, equals(AppShapes.innerCorner));
      expect(middle.topRight.x, equals(AppShapes.innerCorner));

      final trailing = shapes.inRow(2, 3).borderRadius as BorderRadius;
      expect(trailing.topLeft.x, equals(AppShapes.innerCorner));
      expect(trailing.topRight.x, equals(AppShapes.full));
      expect(trailing.bottomRight.x, equals(AppShapes.full));
    });

    test('AppTypography headerTitle style meets Morphe typographic specs', () {
      final style = AppTypography.headerTitle(Colors.white);
      expect(style.fontSize, equals(20.0));
      expect(style.fontWeight, equals(FontWeight.w600));
      expect(style.height, equals(1.3));
    });
  });

  group('SettingsGroup and SettingsCardTile Widgets', () {
    testWidgets('renders connected settings cards with proper hierarchy and interactions', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              children: [
                SettingsCardTile(
                  icon: Icons.palette_outlined,
                  title: 'Visual Theme',
                  subtitle: 'Dark Mode',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => tapped = true,
                ),
                const SettingsCardTile(
                  icon: Icons.storage_rounded,
                  title: 'Storage Directory',
                  subtitle: 'Internal Storage/Download',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Visual Theme'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Storage Directory'), findsOneWidget);
      expect(find.text('Internal Storage/Download'), findsOneWidget);

      await tester.tap(find.text('Visual Theme'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('ConnectedButtonGroup toggles selection seamlessly', (tester) async {
      String selected = 'Option A';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ConnectedButtonGroup<String>(
                  items: const ['Option A', 'Option B', 'Option C'],
                  selectedItem: selected,
                  onSelected: (val) => setState(() => selected = val),
                  labelBuilder: (context, item, isSelected) => Text(item),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(selected, equals('Option B'));
    });
  });
}
