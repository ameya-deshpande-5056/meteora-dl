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
- [x] MediaStore insertion for modern Android scoped storage.

## Phase 4: UI/UX Presentation Layer
- [x] Liquid Glass dark-first theme and Material 3 design tokens.
- [x] Home screen: URL input, clipboard detection, Android share target.
- [x] Downloads screen: Live progress, speed, ETA, pause/resume/cancel controls.
- [x] Media Library screen: Offline video/audio explorer, collections, search.
- [x] Settings screen: Component update manager, channel selector, runtime toggles.

## Phase 5: Media Playback & Optimization
- [x] Android Media3 (ExoPlayer) native playback integration.
- [x] Thumbnail caching and FFprobe metadata extraction.
- [x] Automated unit and integration test suites.
- [x] Performance profiling and APK size optimization.
