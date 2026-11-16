# ADR-005: Material 3 Expressive Design System, Morphe Reference, and Restrained Liquid Glass

## Status
Accepted

## Context
Initial UI prototypes often suffer from generic AI aesthetics: arbitrary neon gradients, excessive glowing borders, random rounded glass cards, floating emoji badges, and heavy full-screen blur filters that cause frame drops on mobile devices. A production-grade Android utility must adhere to native Android design standards, Material 3 Expressive guidelines, strict information hierarchy, accessibility standards, and responsive adaptability.

To achieve reference-grade Material 3 Expressive design, Meteora references the open-source **Morphe App** (`MorpheApp/morphe-manager`), a benchmark Android application implementing Material 3 Expressive patterns in Jetpack Compose.

## Decision
1. **Material 3 Foundation & Morphe Expressive Architecture**:
   - Adopt the official Material 3 color roles (`surface`, `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`, `primary`, `secondary`, `tertiary`, `outline`, `outlineVariant`).
   - Standard 4dp/8dp spacing scale (`AppSpacing`).
   - Material 3 Shape scale (extra-small 4dp, small 8dp, medium 12dp, large 16dp, corner-large-increased 20dp, extra-large 28dp, full 999dp).
   - **Connected Shapes System (`ConnectedShapes`)**: Inspired by Morphe's `ConnectedShapes.kt`, connected item groups (in columns and rows) use outer radii (20dp for cards, 999dp for pills) on exposed group boundaries and nearly-square inner corners (4dp) where adjoining items meet. This forms cohesive segmented surfaces rather than disparate floating boxes.
   - **Settings Groups & Surface Cards (`SettingsGroup`, `ExpressiveSurfaceCard`)**: Sections group related items with a 2dp segment gap (`kSegmentGap`) and hairline borders (`outlineVariant` with low alpha).
   - **Connected Button Groups (`ConnectedButtonGroup`)**: Segmented pickers for download formats with pill connected shapes and spring feedback.
   - **Typography Scale & `headerTitle`**: Implements Morphe's `headerTitle` (`titleLarge` 20sp, weight 600, line height 26sp) to lead cards and section groups without overpowering secondary metadata.
   - **Expressive Motion (`AppMotion`)**: Expressive spring physics (`Cubic(0.34, 1.56, 0.64, 1.0)`), emphasized deceleration, and dialog scale entry (0.95), with automatic zero-duration fallback when reduced-motion is requested.
2. **Restrained Liquid Glass Treatment**:
   - Liquid Glass is restricted to floating navigation bars, URL search anchors, contextual overlays, and modal bottom sheets.
   - Scrolling lists and content cards use lightweight opaque or subtle semi-translucent M3 surface containers with zero real-time backdrop blur, guaranteeing 60/120 FPS scrolling performance across all Android devices.
   - Strict budget: exactly 1 BackdropFilter active per screen view.
3. **Themes & Power Efficiency**:
   - Provide standard M3 Light Mode, M3 Dark Mode, and AMOLED Pure Black mode (`#000000` surface with high-contrast container levels for OLED power efficiency).
4. **Adaptive Navigation**:
   - Support `NavigationBar` for compact portrait screens and `NavigationRail` for wide screens / landscape / tablets.
5. **Usability & States**:
   - Every screen features distinct Loading, Empty, Active, Completed, Offline, and Error states with clear user recovery actions.

## Consequences
### Positive
- Benchmark Material 3 Expressive visual clarity and platform familiarity identical to high-caliber Android apps like Morphe.
- Guaranteed 60/120 FPS performance with zero GPU overdraw or backdrop blur penalties in content lists.
- Full WCAG AA/AAA contrast compliance across all tokens (verified with `contrast.py`).
- Clear component modularity with reusable `ConnectedShapes` and `SettingsGroup` primitives.

### Negative
- Requires maintaining detailed M3 theme tokens and multiple theme variants (Light, Dark, AMOLED).
