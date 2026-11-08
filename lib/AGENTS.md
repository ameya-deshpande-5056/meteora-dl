# Flutter UI Subsystem Instructions (`lib/AGENTS.md`)

## Responsibilities
The `lib/` directory contains the Flutter presentation layer and user interface for Meteora.

## Visual Design Language
- **Liquid Glass Aesthetic**:
  - Dark-first theme with obsidian/slate base (`#0B0E14`, `#121722`).
  - Subtle frosted glass panels with `BackdropFilter` (sigma 10-16), translucent border gradients (`Colors.white.withOpacity(0.08)`), and soft drop shadows.
  - Accent colors: Electric Cyan (`#00D2FF`) and Neon Indigo (`#6366F1`).
- **Material 3 Principles**:
  - M3 navigation bar with 4 primary destinations:
    1. **Home**: URL input field, quick paste button, Android share target handler, recent extraction cards.
    2. **Downloads**: Active queue, paused/completed lists, live speed, remaining time, progress bars, pause/cancel/retry buttons.
    3. **Library**: Offline video/audio explorer, thumbnail previews, codec tags, search, and collections.
    4. **Settings**: Package Update Manager interface, update channel selection (Stable/Nightly/Manual), JS runtime toggle (Deno vs QuickJS-NG), codec preference overrides.
- **Performance Guidelines**:
  - Keep animations lightweight (200-350ms curves like `Curves.easeOutCubic`).
  - Avoid excessive rebuilds; use fine-grained selectors and `const` widget constructors.
  - No bloated shaders or heavy blur hierarchies that drop frames on 60/120Hz displays.
