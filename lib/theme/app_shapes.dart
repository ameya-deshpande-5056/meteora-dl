import 'package:flutter/material.dart';

/// Material 3 Shape Scale Tokens conforming to Android Material 3 Expressive guidelines,
/// inspired by Morphe App's connected shapes architecture.
class AppShapes {
  static const double extraSmall = 4.0;
  static const double innerCorner = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double cornerLargeIncreased = 20.0;
  static const double extraLarge = 28.0;
  static const double full = 999.0;

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(medium),
  );

  static final RoundedRectangleBorder sectionCardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerLargeIncreased),
  );

  static final RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(extraLarge),
  );

  static final RoundedRectangleBorder bottomSheetShape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(extraLarge)),
  );
}

/// Shapes of the members of a connected group: outer corners on the group's own
/// edges, and inner (4dp) corners where two meet, so they visually read as one piece.
/// Directly mirrors Morphe App's `ConnectedShapes` pattern.
class ConnectedShapes {
  final double outerRadius;
  final double innerRadius;

  const ConnectedShapes({
    this.outerRadius = AppShapes.cornerLargeIncreased,
    this.innerRadius = AppShapes.innerCorner,
  });

  /// For a group of buttons or tabs, as round as any other pill button.
  static const ConnectedShapes pill = ConnectedShapes(
    outerRadius: AppShapes.full,
    innerRadius: AppShapes.innerCorner,
  );

  /// For a segmented list or settings group, rounded as the section cards.
  static const ConnectedShapes card = ConnectedShapes(
    outerRadius: AppShapes.cornerLargeIncreased,
    innerRadius: AppShapes.innerCorner,
  );

  /// Shape of the member at [index] of a row of [count].
  RoundedRectangleBorder inRow(int index, int count) {
    if (count <= 1) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(outerRadius),
      );
    }
    if (index == 0) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(outerRadius),
          right: Radius.circular(innerRadius),
        ),
      );
    }
    if (index == count - 1) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(innerRadius),
          right: Radius.circular(outerRadius),
        ),
      );
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(innerRadius),
    );
  }

  /// Shape of the member at [index] of a column of [count].
  RoundedRectangleBorder inColumn(int index, int count) {
    if (count <= 1) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(outerRadius),
      );
    }
    if (index == 0) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(outerRadius),
          bottom: Radius.circular(innerRadius),
        ),
      );
    }
    if (index == count - 1) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(innerRadius),
          bottom: Radius.circular(outerRadius),
        ),
      );
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(innerRadius),
    );
  }
}
