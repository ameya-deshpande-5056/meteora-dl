# Changelog

All notable changes to the Meteora project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
