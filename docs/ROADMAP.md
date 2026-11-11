# Project Roadmap

This roadmap outlines the phased development plan for Meteora.

---

## Phase 1: Foundation & Feasibility (Completed)
- [x] Project initialization with Flutter + Kotlin Android setup.
- [x] Comprehensive agentic repository documentation (`AGENTS.md`, ADRs, architecture specs).
- [x] Modular project separation (`packages/media_engine`, `packages/package_manager`, `packages/media_library`).

## Phase 2: Core Domain Logic & Engine Integration
- [x] Media extraction entity models and typed parsing.
- [x] Intelligent Format Selection algorithm implementation and test suite.
- [x] Package Update Manager (GitHub release client, SHA-256 validation, staging/rollback).

## Phase 3: Android Native Services & Process Architecture
- [x] Kotlin `DownloadForegroundService` with notification lifecycle and persistent recovery.
- [x] Safe `ProcessBuilder` executor for `yt-dlp` and JavaScript solvers.
- [x] JavaScript runtime integration (Deno + QuickJS-NG fallback).
- [x] FFmpeg and FFprobe stream muxing (`-c copy`) and metadata inspection.
- [x] Configurable public `Downloads` (`MediaStore.Downloads` / `Environment.DIRECTORY_DOWNLOADS`) and custom SAF (`ACTION_OPEN_DOCUMENT_TREE`) folder storage via `DownloadStorageManager`.
- [x] Automatic EJS solver caching (`--cache-dir`, `--remote-components ejs:github`) and `HTTP 403` / `HTTP 429` download resilience.

## Phase 4: UI/UX Presentation Layer
- [x] Material 3 Dynamic Color + Frosted Liquid Glass design tokens (`LiquidGlassContainer`, `LiquidGlassAppBar`, floating nav dock, `Choose theme` dialog).
- [x] First-launch setup dialog (`FirstLaunchSetupDialog`) for download folder selection and runtime permissions.
- [x] Home screen: URL input, clipboard detection, Android share target, playlist detection, and simple mode/codec/subtitle pickers.
- [x] Downloads screen: Active & completed tabs, live progress, speed, ETA, cancel/retry controls, and external player launch.
- [x] Media Library screen: Offline video/audio explorer, search, sorting/filtering, and external player handoff.
- [x] Settings screen: Clean Theme picker dialog, Download Location picker/reset, Package Update Manager, and Hardware Diagnostics.

## Phase 5: External Playback, Persistence & Optimization
- [x] External media player launch via `Intent.ACTION_VIEW` chooser + `FileProvider` (replacing bundled Media3/ExoPlayer for lean APK size).
- [x] SQLite persistence (`download_tasks`, `media_items`, `app_settings`) and FFprobe metadata indexing models.
- [x] Automated unit, database, and UI widget test suites.
- [x] Performance profiling and APK size optimization (`--split-per-abi`).
