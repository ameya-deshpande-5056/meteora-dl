# Changelog

All notable changes to the Meteora project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [0.0.4] - 2026-11-16

### Material 3 Expressive Design Overhaul & Graphics Performance

### Added
- **Connected Settings Architecture (MicroG RE & Morphe Style)**: Completely redesigned the Settings interface with grouped `ConnectedGroup` cards featuring contextual corner radii (`connectedTop`, `connectedMiddle`, `connectedBottom`), enhanced typographic hierarchy, semantic icons, and clear visual division between settings domains.
- **Dancing Wavy Progress Indicator (`WavyProgressIndicator`)**:
  - Implemented dynamic dancing sine wave animation during active downloads (`dancing: true`), echoing Google Play Store and Morphe motion aesthetics.
  - Symmetrical geometry with balanced right-side and left-side padding and phase alignment so the wave begins and terminates uniformly.
  - Refined stroke width (3.0dp) for an elegant, thinner profile without visual clutter.
  - Accessible fallback to standard `LinearProgressIndicator` when Android's `disableAnimations` / reduced motion setting is active.
- **In-App "About App" & Check for Updates (`AppUpdateService`)**:
  - Added dedicated About App section in Settings with Meteora app identity, version badges, GitHub links, and Open Source Licenses.
  - Integrated direct GitHub Releases update checker with automatic semantic version comparison, release note dialogs, and direct APK download links.

### Changed
- **Header & Surface Contrast Overhaul**: Removed distracting glass blur from the top app bar and app background, adopting clean Material 3 Expressive surfaces (`SurfaceContainerLowest` / `SurfaceContainerHigh`) with crisp typography and high contrast, while preserving the floating navigation dock.

### Performance & Stability
- **Android BLASTBufferQueue Fix**:
  - Resolved `acquireNextBufferLocked: Can't acquire next buffer. Already acquired max frames 5 max:3 + 2` buffer exhaustion on Android 11–15.
  - Removed conflicting surface-level `Surface.setFrameRate` from `DisplayModeController.kt`, managing high refresh rate (90Hz / 120Hz) cleanly at the Window level (`preferredRefreshRate` and `preferredDisplayModeId`).
  - Statically cached wave geometry (`_cachedMetric`, path, length) in `_MorpheLinearWavyPainter` to avoid 120Hz native `SkPath` and `computeMetrics()` re-allocations on every frame.
  - Added `RepaintBoundary` around `WavyProgressIndicator` and `_TaskCard`, and wrapped offscreen tabs in `TickerMode(enabled: i == currentIndex)` to eliminate off-screen vsync ticks.
- **Cancellation & Native Stream Cleanup**:
  - Handled `InterruptedIOException: read interrupted by close() on another thread` in native stream readers when downloads are cancelled.
  - Cleaned process group teardown to ensure immediate cancellation without noisy stack traces or detached channel warnings.

### Artifacts & Downloads
- `meteora-v0.0.4-arm64-v8a.apk` — Optimized build for modern 64-bit ARM devices (Recommended).
- `meteora-v0.0.4-armeabi-v7a.apk` — Build for legacy 32-bit ARM devices.
- `meteora-v0.0.4-x86_64.apk` — Build for 64-bit x86 emulators and Chromebooks.
- `meteora-v0.0.4-universal.apk` — Universal package containing all architectures.
- `checksums.txt` — SHA-256 cryptographic verification hashes for all APK artifacts.

---

## [0.0.3] - 2026-11-16

### Package Updaters & EJS Refresh Reliability

### Removed
- **Automatic Format Selection**: deleted `IntelligentFormatSelector`, `FormatRecommendation` and their test suite. Downloads now always run the user's explicit video/audio/subtitle selection.
- **Fabricated Settings Data**: removed the hard-coded component version table, the Stable/Nightly channel control, and the Deno/QuickJS runtime picker — none of them changed how extraction or downloads ran.
- **Dead Engine Install Prompt**: removed the Home banner that downloaded an unused yt-dlp binary, plus the oEmbed preview that offered a download with no available formats.

### Added
- **Bundled EJS JavaScript Runtime**: `JsRuntimeResolver` verifies the QuickJS CLI that `youtubedl-android` ships as `libqjs.so` (ELF header + `--version`, executed from `nativeLibraryDir`, the only path a targetSdk 29+ app may exec) and `NativeEngineManager` passes it to every extraction and download as `--js-runtimes quickjs:<path>`, alongside the cached `ejs:github` solver components. Settings reports whether the runtime is ACTIVE or MISSING.
- **iOS-style Liquid Glass**: `LiquidGlassContainer` now composites real backdrop blur, a directional vibrancy gradient, a two-tone specular rim with inset highlight, a top-edge gloss band, and an ambient shadow/glow; `LiquidGlassBackground` paints three soft light blooms for the blur to refract.
- **Material 3 Expressive Wavy Progress (`WavyProgressIndicator`)**: determinate and indeterminate sine-wave progress with a leading cap dot, used for downloads and stream inspection, with a `LinearProgressIndicator` fallback under reduced motion.
- **Retry & Resume**: every task persists its exact yt-dlp argument vector (`download_tasks.command`, with an automatic `ALTER TABLE` migration), so failed, cancelled and interrupted downloads can be restarted from Downloads.
- **Failed Tab**: `DownloadsScreen` gained a third tab, and paused/interrupted tasks are listed in Active with a Resume action instead of vanishing.
- **Library Thumbnails**: media cards show source thumbnails, duration badges, and a metadata line.
- **EJS, FFmpeg & FFprobe Package Updaters**: Extended the Package Update Manager (`packages/package_manager`) so every binary in a package can be updated atomically. `PackageType.ffmpeg` now ships `ffprobe` alongside `ffmpeg`, and `installPackage` downloads + SHA-256 verifies every co-shipped binary before the atomic directory swap; rollback restores the whole package on failure. Single-binary packages (`yt-dlp`, `yt-dlp-ejs`, `deno`, `quickjs-ng`) are unaffected.
- **EJS Refresh Reliability**: Settings "Refresh EJS Components" now wraps the native channel call in `try/catch` (no stuck spinner on `PlatformException`) and shows a `SnackBar` confirmation on success. The `ytdlp-cache` is cleared and re-fetched from `--remote-components ejs:github` on the next extraction/download.

### Performance
- **Blur is now opt-in** (`LiquidGlassContainer.enableBlur`, default off). Only the dock, app bar, search bars and modal sheets/dialogs enable `BackdropFilter`; inline cards render the tint and specular rim without a per-card blur layer, which was the main source of dropped frames.
- **UI notifications throttled to 150ms** per task (SQLite writes already throttled to 1% / 1s), so progress feeds no longer rebuild every visible card on each yt-dlp progress line.
- **Thumbnails decode at display size** (`cacheWidth`) instead of full resolution while scrolling.

### Changed
- **Settings → Download Engine**: shows the real embedded yt-dlp version and performs a real update check, reporting the actual result or error.
- **SQLite Progress Writes**: throttled to state changes, 1% steps or one second, instead of writing on every yt-dlp progress line.
- **Expressive Navigation**: the dock selection capsule and icon scale now animate with a spring curve and haptic feedback; the Settings/Downloads/Library surfaces are glass panels rather than plain cards.

### Fixed
- **Invisible Failures**: download tasks in `error`, `paused` or `cancelled` state were rendered in neither tab, so failures and interrupted transfers disappeared from the UI. They are now always reachable and actionable.
- **Stuck Refresh Spinner**: "Refresh EJS Components" no longer leaves `_isRefreshingEjs` stuck `true` when the method channel errors.

### Artifacts & Downloads
- `meteora-v0.0.3-arm64-v8a.apk` — Optimized build for modern 64-bit ARM devices (Recommended).
- `meteora-v0.0.3-armeabi-v7a.apk` — Build for legacy 32-bit ARM devices.
- `meteora-v0.0.3-x86_64.apk` — Build for 64-bit x86 emulators and Chromebooks.
- `meteora-v0.0.3-universal.apk` — Universal package containing all architectures.
- `checksums.txt` — SHA-256 cryptographic verification hashes for all APK artifacts.

---

## [0.0.2] - 2026-11-11

### Streamlined UX, Accessible Downloads, External Playback & YouTube Resilience

### Added
- **Guided First-Launch Setup (`FirstLaunchSetupDialog`)**: Prompts new users once at first launch (`first_launch_setup_done` persisted in SQLite) to select a destination download folder and grant required runtime permissions (`POST_NOTIFICATIONS`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` on Android 13+, or scoped legacy storage permissions on older Android versions).
- **Simple Mode, Codec & Subtitle Download Selector (`DownloadMode`, `SimpleDownloadCommandBuilder`)**: Allows picking explicit download modes (`Video + Audio`, `Video Only`, `Audio Only`, `Subtitles Only`), video resolution/fps/codec streams, audio bitrate/codec streams, and multi-select creator/auto-generated subtitle languages (`SubtitleTrackInfo`).
- **Configurable Public Downloads & SAF Folder Storage (`DownloadStorageManager`)**: Stages downloads privately during transfer and publishes completed media to Android's public `Downloads` directory (`MediaStore.Downloads` / `Environment.DIRECTORY_DOWNLOADS`) by default, or to any user-chosen folder via Android Storage Access Framework (`ACTION_OPEN_DOCUMENT_TREE`), with a setting to reset back to the default folder.
- **External Media Player Integration (`Intent.ACTION_VIEW` + `FileProvider`)**: Opens completed videos, audio files, and subtitles directly in external apps (e.g., VLC, mpv) via Android's system chooser with read URI grants (`file_paths.xml` and `<queries>` declarations in `AndroidManifest.xml`).
- **SQLite App Settings Persistence (`app_settings` table)**: Stores theme mode (`ThemeManager`) and onboarding state (`DownloadStateManager`), alongside `file_path` persistence on completed download tasks.
- **Liquid Glass Surface System (`LiquidGlassContainer`, `LiquidGlassAppBar`, `LiquidGlassBackground`)**: Real-time `BackdropFilter` frosted blur, directional sheen gradients, specular rim borders, floating glass navigation dock/rail (`AdaptiveScaffold`), glass search/URL bars, and reduced-motion fallbacks.
- **Expanded Automated Tests**: Added `test/user_requirements_test.dart`, `packages/media_engine/test/download_mode_test.dart`, and SQLite settings coverage in `packages/media_library/test/database_test.dart`.

### Changed
- **Theme Switcher UI**: Replaced the compact 4-option segmented button in Settings with a clean `Theme` list tile opening a Liquid Glass `Choose theme` dialog with preview swatches (`Follow System`, `Light Mode`, `Dark Mode`, `AMOLED Black`).
- **Format & Bitrate Badge Readability**: Enforced single-line non-wrapping video resolution/fps labels (`1080p60`, `720p60`, etc.) and ellipsis-free two-line audio bitrate badges (`kbps` placed beneath the numeric rate).
- **YouTube Runtime & Network Defaults (`NativeEngineManager`)**: Explicitly sets a persistent `ytdlp-cache` `--cache-dir` (overriding `youtubedl-android`'s `--no-cache-dir`), enables `--remote-components ejs:github` for updated EJS challenge solver bundles, applies `--force-ipv4` when an active non-loopback IPv4 interface is present, and adds `--sleep-subtitles 2` plus download/fragment/extractor retries (`--retries 5`, `--fragment-retries 10`, `--extractor-retries 3`).

### Fixed
- **YouTube `HTTP Error 403: Forbidden` Video Data Errors**: Fixed failed `n`-challenge solving on updated `yt-dlp` binaries by persisting EJS solver components, and added automatic staging cleanup plus fallback client retry (`--extractor-args youtube:player_client=tv,android_vr,visionos` with mode-appropriate format selectors and `--force-ipv4`) in `DownloadForegroundService`.
- **Subtitle `HTTP Error 429` Rate-Limit Recovery**: Automatically retries media downloads without subtitle flags when YouTube `timedtext` returns HTTP 429, and surfaces an actionable rate-limit message for subtitles-only tasks.

### Removed
- **Bundled Android Media3 / ExoPlayer Playback**: Removed `androidx.media3:media3-exoplayer`, `androidx.media3:media3-ui`, `PlayerActivity.kt`, and `activity_player.xml` in favor of launching the user's installed external media players.

### Artifacts & Downloads
- `meteora-v0.0.2-arm64-v8a.apk` — Optimized build for modern 64-bit ARM devices (Recommended).
- `meteora-v0.0.2-armeabi-v7a.apk` — Build for legacy 32-bit ARM devices.
- `meteora-v0.0.2-x86_64.apk` — Build for 64-bit x86 emulators and Chromebooks.
- `meteora-v0.0.2-universal.apk` — Universal package containing all architectures.
- `checksums.txt` — SHA-256 cryptographic verification hashes for all APK artifacts.

---

## [0.0.1] - 2026-11-08

### Initial Production-Grade Release

Welcome to the inaugural release of **Meteora (MeteoraDL)** — a lightweight, open-source Android media downloader designed with a modern Flutter UI, robust Kotlin native services, embedded Python 3 runtime, FFmpeg muxing, SQLite task persistence, and Android Media3 playback.

---

### Highlights & Key Capabilities

#### 1. Universal Media Extraction Engine (yt-dlp NDK)
- **Embedded Python 3 & yt-dlp**: Bundles CPython 3 and `yt-dlp` directly inside the APK via the native NDK stack (`youtubedl-android`). No Termux, root, or external dependencies required.
- **1,000+ Supported Websites**: Out-of-the-box extraction and downloading from YouTube, Instagram, TikTok, Twitter/X, Bilibili, Reddit, SoundCloud, Twitch, Vimeo, and more.
- **In-App Over-The-Air Engine Updates**: Update the embedded `yt-dlp` binary dynamically from official upstream channels directly within Settings without reinstalling the entire app.
- **Zero Shell Concatenation**: All process execution uses structured, typed argument vectors via `YoutubeDLRequest` with zero shell interpolation or command injection vulnerabilities.

#### 2. Lossless Audio & Video Muxing (FFmpeg)
- **Embedded FFmpeg Engine**: Bundles precompiled `libffmpeg.so` for all Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
- **Direct Stream Copy**: Automatically merges separate video and audio CDN streams (e.g. 1080p, 1440p, 4K) using `-c copy` without unnecessary re-encoding, preserving exact original fidelity and saving CPU/battery.

#### 3. Intelligent Format Selection Engine
- **Hardware-Aware Recommendation**: Evaluates device display resolution, refresh rate, and hardware-accelerated codecs (AV1, VP9, HEVC, AVC, Opus, AAC).
- **Network & Storage Constraints**: Considers unmetered Wi-Fi vs. metered cellular data and available disk storage to prevent data overages and disk full errors.
- **Adaptive Quality Profiles**: Supports Best Overall, Space Saver, Audio Only, and Manual Stream Picker bottom sheet.

#### 4. Persistent Background Download Service
- **Kotlin `DownloadForegroundService`**: Persistent background downloading with live notification progress bars, current throughput (MB/s), and estimated time remaining (ETA).
- **OEM Battery Protection**: Acquires high-performance Wi-Fi locks and partial wake locks with automatic safety timeouts to prevent background termination by aggressive OS task killers.
- **Instant Cancellation & Cleanup**: Terminate downloads immediately via native process destruction (`destroyProcessById`).

#### 5. Material 3 Expressive UI & Restrained Liquid Glass
- **Dynamic Theming (Monet)**: Integrates Material You dynamic wallpaper color extraction on Android 12+ devices with seamless fallbacks.
- **AMOLED Dark Mode**: True pitch-black (`#000000`) theme for maximum OLED battery savings alongside refined Light and Dark themes.
- **Restrained Liquid Glass**: Translucent, depth-aware surfaces for bottom navigation bars, search bars, and modal sheets with automatic fallbacks for accessibility and reduced motion.
- **Adaptive Layout**: Responsive interface utilizing `NavigationBar` in portrait and `NavigationRail` on tablets and foldable displays.

#### 6. Smart URL Ingestion & Clipboard Detection
- **Android Share Sheet Target**: Accepts shared media links from any external browser, social media app, or video client.
- **Smart Clipboard Detection**: Detects copied media links on app resume with a non-intrusive floating snackbar for one-tap inspection.

#### 7. Media Library, SQLite Persistence & Android Media3
- **Local SQLite / Drift Schema**: ACID-compliant local database for atomic task persistence, progress checkpoints, and media item metadata cataloging.
- **Android MediaStore & Scoped Storage**: Native integration for Android 10-15 Scoped Storage, publishing downloaded media directly to `/Movies/Meteora` and `/Music/Meteora`.
- **Integrated Android Media3 Player**: Built-in ExoPlayer native playback activity for video and audio playback.

---

### Artifacts & Downloads
- `meteora-v0.0.1-arm64-v8a.apk` — Optimized build for modern 64-bit ARM devices (Recommended).
- `meteora-v0.0.1-armeabi-v7a.apk` — Build for legacy 32-bit ARM devices.
- `meteora-v0.0.1-x86_64.apk` — Build for 64-bit x86 emulators and Chromebooks.
- `meteora-v0.0.1-universal.apk` — Universal package containing all architectures.
- `checksums.txt` — SHA-256 cryptographic verification hashes for all APK artifacts.
