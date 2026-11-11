# Flutter UI Subsystem Instructions (`lib/AGENTS.md`)

## Responsibilities
The `lib/` directory contains the Flutter presentation layer and user interface for Meteora.

## Visual Design Language
- **Liquid Glass & Material 3 Expressive**:
  - Uses Material 3 `ColorScheme` tokens powered by Android 12+ wallpaper Dynamic Color (`DynamicColorBuilder`) with a Deep Tech Azure seed (`#007A99`) fallback, plus **Follow System**, **Light Mode**, **Dark Mode**, and **AMOLED Black** (`#000000`) persisted via `ThemeManager` in SQLite.
  - Real-time `BackdropFilter` frosted blur, directional sheen gradients, specular rim borders, and subtle elevation shadows via `LiquidGlassContainer`, `LiquidGlassAppBar`, and `LiquidGlassBackground` — applied to floating navigation chrome, URL/search bars, and modal dialogs/sheets, with automatic reduced-motion fallbacks (`disableAnimations`).
- **Material 3 Principles**:
  - Adaptive floating navigation (`AdaptiveScaffold`: bottom Liquid Glass dock on phones, floating `NavigationRail` on wide displays) with 4 primary destinations:
    1. **Home**: URL input field, quick paste button, Android share target handler, playlist detection, and simple Download Mode / Video / Audio / Subtitle pickers (`DownloadMode`).
    2. **Downloads**: Active & completed tabs, live speed, remaining time, progress bars, cancel/retry/remove actions, and external player launch for completed items.
    3. **Library**: Offline video/audio explorer, search bar, type/sort filters, external player opening, and file deletion.
    4. **Settings**: Clean `Theme` picker dialog, `Download Location` picker/reset (SAF & public `Downloads`), Package Update Manager interface (Stable/Nightly), JS runtime selector (Deno vs QuickJS-NG), and Hardware Diagnostics.
- **First-Launch Onboarding**:
  - `FirstLaunchSetupDialog` prompts once on initial install to configure the destination folder and request required runtime permissions (`POST_NOTIFICATIONS` + media read/storage permissions).
- **Performance Guidelines**:
  - Keep animations lightweight (200-350ms curves like `Curves.easeOutCubic`).
  - Avoid excessive rebuilds; use fine-grained selectors and `const` widget constructors.
  - No bloated shaders or heavy blur hierarchies that drop frames on 60/120Hz displays.
