# Flutter UI Subsystem Instructions (`lib/AGENTS.md`)

## Responsibilities
The `lib/` directory contains the Flutter presentation layer and user interface for Meteora.

## Visual Design Language
- **Liquid Glass & Material 3 Expressive**:
  - Uses Material 3 `ColorScheme` tokens powered by Android 12+ wallpaper Dynamic Color (`DynamicColorBuilder`) with a Deep Tech Azure seed (`#007A99`) fallback, plus **Follow System**, **Light Mode**, **Dark Mode**, and **AMOLED Black** (`#000000`) persisted via `ThemeManager` in SQLite.
  - iOS-style Liquid Glass via `LiquidGlassContainer`, `LiquidGlassAppBar`, and `LiquidGlassBackground`: real-time `BackdropFilter` blur, directional vibrancy gradient, two-tone specular rim with an inset highlight stroke and a top-edge gloss band, and an ambient shadow/glow. Applied to cards, navigation chrome, URL/search bars, and modal dialogs/sheets, with automatic reduced-motion fallbacks (`disableAnimations`) that swap blur for an opaque tint.
- **Material 3 Expressive motion & progress**:
  - `WavyProgressIndicator` (determinate + indeterminate) is the only progress indicator for downloads and stream inspection; it falls back to `LinearProgressIndicator` under reduced motion.
  - Motion tokens live in `app_motion.dart` (`AppMotion.spring`, `emphasized`, durations). Numeric readouts use `FontFeature.tabularFigures()` so speed/percent digits do not jitter.
- **Material 3 Principles**:
  - Adaptive floating navigation (`AdaptiveScaffold`: bottom Liquid Glass dock on phones, floating `NavigationRail` on wide displays) with 4 primary destinations:
    1. **Home**: URL input field, quick paste button, Android share target handler, playlist detection, and simple Download Mode / Video / Audio / Subtitle pickers (`DownloadMode`).
    2. **Downloads**: Active / Completed / Failed tabs, wavy progress, live speed and ETA, cancel, retry or resume from each task's persisted `yt-dlp` command, dismiss, and external player launch for completed items.
    3. **Library**: Offline video/audio explorer with thumbnails and duration badges, search bar, type/sort filters, external player opening, and removing entries from the library (the downloaded file itself is left in place and never claimed to be deleted).
    4. **Settings**: Clean `Theme` picker dialog, `Download Location` picker/reset (SAF & public `Downloads`), embedded yt-dlp engine status with a real update check, the bundled QuickJS EJS runtime status, and Hardware Diagnostics.
- **First-Launch Onboarding**:
  - `FirstLaunchSetupDialog` prompts once on initial install to configure the destination folder and request required runtime permissions (`POST_NOTIFICATIONS` + media read/storage permissions).
- **Refresh Rate**: the native window requests the display's highest supported refresh rate (see `DisplayModeController`), and every animation duration/ticker therefore follows the real panel rate; Hardware Diagnostics shows the active rate against the panel maximum.
- **Performance Guidelines**:
  - Keep animations lightweight (200-350ms curves like `Curves.easeOutCubic`).
  - `LiquidGlassContainer.enableBlur` is **opt-in and off by default**. Only chrome floating over moving content (dock, sheets, dialogs, app bar) may enable the `BackdropFilter`; inline cards use the tint + specular rim only. A blur per card is the largest source of jank on mid-range GPUs.
  - Progress events from the native service are throttled twice: SQLite writes at 1% / 1s, and `notifyListeners()` at 150ms, so a 20 fps progress feed never rebuilds a list 20 times a second.
  - Decode remote thumbnails at display size (`cacheWidth`) to avoid full-resolution decode jank while scrolling.
