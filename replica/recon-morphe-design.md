# Morphe App Reconnaissance: Material 3 Expressive Design Architecture

## Overview
- **Application**: Morphe Manager (`MorpheApp/morphe-manager`)
- **Ecosystem**: Android / Kotlin / Jetpack Compose / Material 3 Expressive
- **Design Philosophy**: Deep adherence to Material Design 3 Expressive specifications, characterized by dynamic theming (Material You / Monet), AMOLED pure black support, connected geometric shapes (`ConnectedShapes`), spring-based motion curves, grouped surface containers, and progressive disclosure between simple and advanced configurations.

---

## 1. Material 3 Expressive Foundations in Morphe

### 1.1 Color System & Theming
- **Dynamic Color**: Adopts Android 12+ wallpaper color extraction (`dynamicDarkColorScheme` / `dynamicLightColorScheme`) with graceful fallbacks.
- **AMOLED Pure Black**: Enforces true `#000000` background and surface with distinct container levels (`surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`) so cards have visible separation without heavy drop shadows.
- **Tonal Elevation & Outlines**: Uses tonal surface shifts combined with delicate outlines (`outlineVariant.copy(alpha = 0.25f)` or subtle accent borders) rather than muddy drop shadows.

### 1.2 Shape Scale & Connected Shapes System
Morphe introduces an expressive **Connected Shapes** system (`ConnectedShapes.kt`):
- **Outer Radius**:
  - `CornerLargeIncreased`: `20.dp` (Used for section cards, group blocks)
  - `Pill`: `50%` / `CornerSize(50)` (Used for button groups, action pills, segmented controls)
  - `CornerExtraLarge`: `28.dp` (Used for bottom sheets, modal dialogs)
- **Inner Radius**:
  - `InnerCorner`: `4.dp` (Corners where two connected group items meet, nearly square so they visually read as a cohesive block)
- **Grouping Logic**:
  - **In Row (`ConnectedShapes.inRow(index, count)`)**:
    - Leading item: rounded on left (outer), nearly square on right (`4.dp`).
    - Middle item: nearly square on both left and right (`4.dp`).
    - Trailing item: nearly square on left (`4.dp`), rounded on right (outer).
    - Single item: fully rounded on all sides.
  - **In Column / Grouped List (`ConnectedShapes.inColumn(index, count)`)**:
    - Top item: rounded top corners (outer), square bottom corners (`4.dp`).
    - Middle item: square top and bottom corners (`4.dp`).
    - Bottom item: square top corners (`4.dp`), rounded bottom corners (outer).
    - Single item: rounded on all corners.

### 1.3 Expressive Motion System
- Uses spring-based physics rather than linear ease curves:
  - `spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMedium)`
  - Material 3 Emphasized deceleration: `Cubic(0.05, 0.7, 0.1, 1.0)`
  - Material 3 Emphasized exit: `Cubic(0.3, 0.0, 0.8, 0.15)`
- `animateCornersAsState`: Animates shape corner radii smoothly between states without recomposition jank.
- Reduced Motion respect: Scales animation durations to zero when accessibility reduced-motion is active.

### 1.4 Typography Hierarchy
- **Header Title**: `titleLarge.copy(fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.SemiBold)` — heads section cards, group blocks, and dialogs without dwarfing the `bodyMedium` secondary label beneath it.
- **Large Headlines / Wordmarks**: Clean, modern typography with clear visual weight.
- **Body & Metadata**: High contrast `bodyMedium` (14-16sp) paired with `bodySmall` / `labelSmall` in `onSurfaceVariant`.

---

## 2. Component Inventory

| Component | Description | Expressive Details |
|---|---|---|
| `SettingsGroup` / `ListSegment` | Grouped surface cards for related preferences and settings | Items within a section connect using `ConnectedShapes.Card.inColumn`, separated by `SegmentGap` (`2.dp`) and subtle hairline dividers |
| `ConnectedButtonGroup` | Segmented button or tab row | Connected pill or rounded buttons with animated indicator / active container fill |
| `HeaderBar` & Search Field | Top app bar with integrated search | Wordmark / title with compact action icons and floating pill search input |
| `SurfaceCard` / `SectionCard` | Base elevated container | Elevation 0–2dp, surface container color, 20dp outer corners, hairline outline |
| `WavyProgress` | Wavy progress bar for downloads and analysis | Sine-wave traveling animation for indeterminate, smooth continuous wave for determinate |
| `StatusCircleIcon` & `StatusBadge` | Compact status indicator | Circle or squircle container with toned container background and high-contrast icon/label |
| `ToggleRow` / `SettingsSwitchItem` | List tile with toggle or chevron | Squircle icon container, title, subtitle, and trailing switch with check/close iconography |

---

## 3. Implementation in Meteora DL
Meteora DL will map these Morphe paradigms into Flutter:
1. `AppShapes`: Introduce `ConnectedShapes` (`inRow`, `inColumn`, `outerLarge = 20.0`, `innerSmall = 4.0`).
2. `AppTypography`: Add `headerTitle` token.
3. `AppMotion`: Spring curve tokens matching Morphe's spring physics.
4. `ConnectedCard` / `SettingsGroup`: Reusable grouped list card widget for settings and dialogs.
5. `ConnectedButtonGroup`: Segmented download format mode switcher.
