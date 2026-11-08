# Meteora ⚡
> Lightweight, high-performance, open-source Android media downloader powered by yt-dlp.

Meteora is an elegant, native-feeling Android application built with **Flutter**, **Kotlin**, **yt-dlp**, and modern media tooling. Designed with a dark-first Liquid Glass aesthetic, it delivers fast media extraction, intelligent format selection, offline background downloading, independent in-app engine updates, and integrated media playback via Android Media3.

---

## ✨ Features

- 🎥 **Universal Media Extraction**: Supports YouTube, Instagram, Bilibili, TikTok, Reddit, X (Twitter), and hundreds of other yt-dlp-supported sites.
- ⚡ **Native Execution & Background Downloads**: Runs downloads via an Android Foreground Service with pause, resume, retries, and device reboot recovery.
- 🧩 **On-Device JavaScript Challenge Solving**: Powered by **Deno** and **QuickJS-NG** with `yt-dlp-ejs` to solve YouTube player signatures and dynamic throttling (`n` parameter) challenges without external web proxies.
- 🧠 **Intelligent Format Selection**: Recommends the highest quality stream matching your device screen resolution, hardware codec support (AV1, VP9, HEVC, AVC), storage limits, and network type without unnecessary transcoding.
- 🔄 **Self-Updating Component Engine**: Independently update `yt-dlp`, `yt-dlp-ejs`, `deno`, `quickjs-ng`, and `ffmpeg/ffprobe` from official GitHub releases (Stable, Nightly, or Manual) with atomic staging and rollback.
- 🎞️ **Direct Stream Merging**: Merges split video and audio streams seamlessly using **FFmpeg** stream copying (`-c copy`) without re-encoding overhead.
- 📂 **Integrated Media Library & Player**: Embedded **Android Media3 (ExoPlayer)** playback, FFprobe media metadata extraction, search, filtering, and collections.
- 🎨 **Liquid Glass UI**: Material 3 dark-first visual direction with subtle translucency, restrained depth, and fluid 60/120 FPS transitions.

---

## 🏗️ Architecture Overview

```
meteora-dl/
├── android/                   # Kotlin native services, Foreground Service, ProcessBuilder
├── lib/                       # Flutter UI presentation layer (Liquid Glass, Material 3)
├── packages/
│   ├── media_engine/          # yt-dlp extraction parser, Intelligent Format Selection
│   ├── package_manager/       # Package Update Manager (GitHub releases, staging, rollback)
│   └── media_library/         # Drift/SQLite storage, FFprobe metadata, collections
└── docs/                      # Comprehensive technical architecture and ADRs
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (version 3.41+ recommended)
- [Android SDK](https://developer.android.com/studio) (compileSdk 35, minSdk 24)
- Java OpenJDK 21
- Android device or emulator running Android 7.0+ (ARM64 recommended)

### Build and Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/meteora-app/meteora-dl.git
   cd meteora-dl
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run unit tests**:
   ```bash
   flutter test
   ```

4. **Launch on connected Android device**:
   ```bash
   flutter run
   ```

5. **Build optimized ARM64 release APK**:
   ```bash
   flutter build apk --release --target-platform android-arm64 --split-per-abi
   ```

---

## 📜 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Building & Toolchain](docs/BUILDING.md)
- [Android Integration & Foreground Service](docs/ANDROID_INTEGRATION.md)
- [yt-dlp Integration & Execution](docs/YTDLP_INTEGRATION.md)
- [JavaScript Runtime & EJS Guide (Deno / QuickJS-NG)](docs/JAVASCRIPT_RUNTIME.md)
- [FFmpeg / FFprobe Merging & Metadata](docs/FFMPEG_INTEGRATION.md)
- [Package Update Manager & Staging](docs/PACKAGE_UPDATES.md)
- [Security Guidelines](docs/SECURITY.md)
- [Project Roadmap](docs/ROADMAP.md)
- [Architecture Decision Records (ADRs)](docs/DECISIONS/)

---

## 🛡️ License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0-or-later). See [LICENSE](LICENSE) for details. Third-party components retain their respective upstream licenses.
