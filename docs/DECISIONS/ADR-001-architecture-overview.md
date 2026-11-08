# ADR-001: Modular Subsystem Boundaries and Multi-Package Layout

## Status
Accepted

## Context
Meteora requires a clean separation of concerns among the Flutter presentation UI, domain business logic (format selection, download queue, library management), and native Android capabilities (process execution, foreground service, MediaStore, ExoPlayer/Media3). Combining all logic into a monolithic `lib/` directory would introduce tight coupling, hinder automated testing, and make standalone component reuse impossible.

## Decision
We adopt a multi-package modular architecture:
1. `meteora` (root app): Flutter UI layer adhering to Material 3 and Liquid Glass aesthetics.
2. `packages/media_engine`: Pure Dart domain package handling yt-dlp JSON parsing, stream pairing, and Intelligent Format Selection.
3. `packages/package_manager`: Pure Dart domain package handling GitHub release queries, checksum validation, and atomic staging directory swaps.
4. `packages/media_library`: Drift/SQLite-backed offline media storage, playlist management, and FFprobe metadata indexing.
5. `android/`: Kotlin native layer handling `DownloadForegroundService`, `ProcessBuilder`, and MediaStore integration.

## Consequences
### Positive
- Strict dependency boundaries: Domain logic can be unit-tested without launching Flutter widgets or native Android emulators.
- Independent evolvability of the format selection rules and package updater.
- Clean platform channel contracts between Dart and Kotlin.

### Negative
- Requires maintaining multiple `pubspec.yaml` files and managing path-based dependency resolution.
