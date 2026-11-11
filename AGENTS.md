# AGENTS.md — Canonical Engineering & AI Guidelines for Meteora

Welcome to **Meteora**, a lightweight, open-source Android media downloader powered by **yt-dlp**, **Flutter**, **Kotlin**, **Deno** / **QuickJS-NG**, **FFmpeg/FFprobe**, **SQLite (`sqlite3`)**, and Android's external media player integration (`Intent.ACTION_VIEW` + `FileProvider`).

This document is the **single source of truth** for all human and AI agents working in this repository. All other agent instruction files (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) must refer to this document.

---

## 1. Architectural Principles & Boundaries

Meteora is organized into strict, decoupled modular subsystems:

```
meteora-dl/
├── android/                   # Kotlin native engine, ForegroundService, process management
├── lib/                       # Flutter UI presentation layer (Liquid Glass, M3)
├── packages/
│   ├── media_engine/          # yt-dlp extraction models, format selection algorithm
│   ├── package_manager/       # Self-updating engine for binaries (yt-dlp, deno, ffmpeg)
│   └── media_library/         # Media browser, FFprobe metadata extraction, collections
├── docs/                      # Technical specs, architecture records (ADRs)
└── test/                      # Unit, widget, and integration tests
```

### Subsystem Boundaries:
1. **Flutter Presentation Layer (`lib/`)**:
   - Manages UI state, routes, visual design (Dark-first Liquid Glass, Material 3).
   - Must never directly invoke shell commands or manipulate raw OS processes.
   - Communicates with domain packages (`media_engine`, `package_manager`, `media_library`) and native services via typed repository interfaces and platform channels.
2. **Media Engine (`packages/media_engine`)**:
   - Models extraction requests, formats, audio/video streams, subtitle tracks, thumbnails, and simplified `DownloadMode` builders (`SimpleDownloadCommandBuilder`).
   - Contains the **Intelligent Format Selection Engine** (analyzes screen resolution, hardware codec compatibility, storage, network metered status).
3. **Package Update Manager (`packages/package_manager`)**:
   - Manages standalone updates for `yt-dlp`, `yt-dlp-ejs`, `deno`, `quickjs-ng`, `ffmpeg`, and `ffprobe`.
   - Fetches from official GitHub releases, validates SHA-256 checksums, downloads into staging directories, performs atomic swap, and retains rollback capability.
4. **Media Library (`packages/media_library`)**:
   - Manages indexed downloaded media, metadata persistence via SQLite (`MeteoraDatabase`), app settings (`app_settings`), tags/collections, and thumbnail caching.
5. **Android Native Engine (`android/`)**:
   - `DownloadForegroundService`: Persistent execution with notification controls, wake locks, crash/error recovery (`403`/`429` fallbacks), and retry handling.
   - Secure process execution via `ProcessBuilder` and typed `YoutubeDLRequest` argument vectors (no shell interpolation), with cached `ejs:github` solver components (`--cache-dir`).
   - Native `DownloadStorageManager` (`MediaStore.Downloads` & SAF `ACTION_OPEN_DOCUMENT_TREE`) integration for Android 10-15 scoped storage.
   - External media player launch via `Intent.ACTION_VIEW` chooser + `FileProvider`.

---

## 2. Technology Choices & Constraints

- **Flutter / Dart**: 3.41+ / Dart 3.11+. Null-safety required.
- **Android Target**: minSdk 24 (Android 7.0), targetSdk 35 (Android 15), compileSdk 35.
- **Primary Architecture**: ARM64 (`arm64-v8a`) prioritized; ABI splits supported for size minimization.
- **Python Runtime**: Embedded Android Python (`libpython.so`) or standalone binary managed in internal storage.
- **JavaScript Challenge Solver**:
  - Primary: `deno` configured with `yt-dlp-ejs`.
  - Lightweight alternative: `quickjs-ng` (`qjs`) for minimal footprint and low RAM overhead.
  - Security rule: JS runtimes must run sandboxed without arbitrary network or host file permissions.
- **Media Merging**: FFmpeg stream copy (`-c copy`) without re-encoding unless format conversion is explicitly requested.
- **Storage**: SQLite (`MeteoraDatabase`) in protected app storage, plus `MediaStore.Downloads` and Storage Access Framework (`ACTION_OPEN_DOCUMENT_TREE`) for public and user-selected directories.

---

## 3. Security & Safety Rules

1. **Zero Shell Command Construction**:
   - **NEVER** use `sh -c "yt-dlp $URL"`, `Runtime.getRuntime().exec(String)` or String concatenation to execute processes.
   - **ALWAYS** pass arguments as a structured array or `List<String>` through `ProcessBuilder`.
2. **URL Sanitization & Validation**:
   - Validate URLs before passing to any extraction or network engine. Block `file://`, `content://`, or local network loops (`127.0.0.1`, `169.254.169.254`) unless explicitly verified.
3. **Storage Access Integrity**:
   - Respect Android Scoped Storage. Use `MediaStore` or `StorageAccessFramework` for writing to public media directories. Never attempt to write directly to arbitrary root paths.
4. **Binary & Asset Verification**:
   - In package updates, verify downloaded artifacts against official cryptographic hashes (SHA-256) before staging or executing.
5. **No CAPTCHA Bypassing**:
   - yt-dlp and JS challenge solving are for player script execution (e.g. `n` parameter and signature deciphering), NOT for bypassing CAPTCHAs, bot gates, or login firewalls. Report authentication walls gracefully to the user.

---

## 4. Coding Conventions & Standards

- **Dart/Flutter**:
  - Effective Dart rules strictly enforced (`analysis_options.yaml`).
  - Dark-first theme with semantic color tokens. Avoid hardcoded hex colors in widgets.
  - Use `const` constructors wherever possible.
  - Prefer immutable state models with `@immutable` or Dart 3 records / data classes.
- **Kotlin**:
  - Idiomatic Kotlin with Coroutines and Flow.
  - No blocking operations on the Main thread.
  - Use AndroidX libraries, Lifecycle-aware components, and Jetpack standard APIs.
- **Error Handling**:
  - Use sealed class / Result types for domain operations: `Result.Success(val data)` vs `Result.Failure(val error)`.
  - Never swallow exceptions silently. Log meaningful diagnostic details.

---

## 5. Development Workflow & Commands

- **Fetch dependencies**: `flutter pub get`
- **Run static analysis**: `flutter analyze`
- **Run tests**: `flutter test`
- **Run package tests**:
  - `(cd packages/media_engine && flutter test)`
  - `(cd packages/package_manager && flutter test)`
  - `(cd packages/media_library && flutter test)`
- **Build debug APK**: `flutter build apk --debug`
- **Build ARM64 release APK**: `flutter build apk --release --target-platform android-arm64 --split-per-abi`

---

## 6. Operating Rules for Agents

1. **Inspect before changing**: Understand existing code and documentation before applying edits.
2. **Verify with tests**: Every new feature or fix must include automated unit or integration tests.
3. **No phantom features**: Never claim a feature is complete until verified with working code and passing tests.
4. **Document architectural shifts**: Log major design decisions in `docs/DECISIONS/` using the ADR format.
5. **Keep dependencies lean**: Do not pull heavy third-party packages into pubspec without clear justification.
