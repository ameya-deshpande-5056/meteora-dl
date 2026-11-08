# ADR-005: Material 3 Expressive Design System and Restrained Liquid Glass

## Status
Accepted

## Context
Initial UI prototypes often suffer from generic AI aesthetics: arbitrary neon gradients, excessive glowing borders, random rounded glass cards, floating emoji badges, and heavy full-screen blur filters that cause frame drops on mobile devices. A production-grade Android utility must adhere to native Android design standards, Material 3 Expressive guidelines, strict information hierarchy, accessibility standards, and responsive adaptability.

## Decision
1. **Material 3 Foundation**:
   - Adopt the official Material 3 color roles (`surface`, `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`, `primary`, `secondary`, `tertiary`, `outline`, `outlineVariant`).
   - Standard 4dp/8dp spacing scale.
   - Material 3 Shape scale (extra-small 4dp, small 8dp, medium 12dp, large 16dp, extra-large 28dp, full 999dp).
   - Strict typography scale based on Roboto / system font without artificial oversized text.
2. **Restrained Liquid Glass Treatment**:
   - Liquid Glass is restricted to floating navigation bars, URL search anchors, contextual overlays, and modal bottom sheets.
   - Scrolling lists and content cards use lightweight opaque or subtle semi-translucent M3 surface containers with zero real-time backdrop blur, guaranteeing 60/120 FPS scrolling performance across all Android devices.
   - Graceful fallback for devices with reduced motion or low GPU fill rates.
3. **Themes & Power Efficiency**:
   - Provide standard M3 Light Mode, M3 Dark Mode, and AMOLED Pure Black mode (`#000000` surface with high-contrast elements for OLED power efficiency).
4. **Adaptive Navigation**:
   - Support `NavigationBar` for compact portrait screens and `NavigationRail` for wide screens / landscape / tablets.
5. **Usability & States**:
   - Every screen features distinct Loading, Empty, Active, Completed, Offline, and Error states with clear user recovery actions.

## Consequences
### Positive
- Production-grade visual clarity and platform familiarity for Android users.
- Guaranteed 60/120 FPS performance with minimal GPU overdraw and battery consumption.
- Seamless accessibility, contrast compliance (WCAG AA), and support for system font scaling.

### Negative
- Requires maintaining detailed M3 theme tokens and multiple theme variants (Light, Dark, AMOLED).
