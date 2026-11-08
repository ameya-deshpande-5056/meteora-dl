import 'package:flutter/material.dart';

/// Material 3 Shape Scale Tokens
class AppShapes {
  static const double extraSmall = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 28.0;
  static const double full = 999.0;

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(medium),
  );

  static final RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(extraLarge),
  );

  static final RoundedRectangleBorder bottomSheetShape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(extraLarge)),
  );
}
