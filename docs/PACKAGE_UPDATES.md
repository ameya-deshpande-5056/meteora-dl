# Package Update Manager & Atomic Staging

## 1. Motivation
Streaming platforms frequently alter their internal APIs and player obfuscation scripts. If an app depends on routine Google Play / APK releases to update its extractor, it risks prolonged downtime when an extractor breaks.

Meteora implements an independent, in-app Package Update Manager for:
- `yt-dlp`
- `yt-dlp-ejs`
- `deno`
- `quickjs-ng`
- `ffmpeg` & `ffprobe`

---

## 2. Directory Layout

All active, staged, and backup packages reside within the app's protected internal storage (`context.filesDir`):

```
/data/user/0/dev.meteora/files/packages/
├── active/
│   ├── ytdlp/
│   │   ├── yt-dlp
│   │   └── version.json
│   ├── ejs/
│   │   ├── yt-dlp-ejs.bundle.js
│   │   └── version.json
│   ├── js_runtime/
│   │   ├── deno (or qjs)
│   │   └── version.json
│   └── ffmpeg/
│       ├── ffmpeg
│       ├── ffprobe
│       └── version.json
├── staging/
│   └── ... (incoming downloads undergoing verification)
└── backup/
    └── ... (previous known-good version for rollback)
```

> **Co-shipped binaries are updated atomically.** `ffmpeg` and `ffprobe` ship together in a single
> `yt-dlp/FFmpeg-Builds` release archive and are modeled as one `PackageType.ffmpeg` unit. The
> package manager downloads, SHA-256 verifies, and stages *every* binary in the package before the
> atomic directory swap, so a partial or corrupt download can never leave `active/ffmpeg/` in a
> mixed state (e.g. new `ffmpeg` with stale `ffprobe`). Rollback restores the entire package from
> `backup/ffmpeg/`.
>
> **Note on archive extraction:** `yt-dlp/FFmpeg-Builds` publishes `ffmpeg`+`ffprobe` inside a
> `.tar.xz` (Linux) / `.zip` (Windows) archive rather than as standalone executable assets. Pure
> Dart cannot extract `.tar.xz` without native code, so the native integration layer is responsible
> for extracting the archive into the separate `ffmpeg` and `ffprobe` binaries before the Dart
> package manager installs/verifies each one. EJS (`.js` bundle), Deno and QuickJS-NG are single
> binary/script assets and flow through the updater directly.

---

## 3. Update Channels

Users can select their preferred release channel per package or globally:
- **Stable**: Official stable releases from upstream GitHub tags.
- **Nightly**: Daily automated builds for rapid adaptation to YouTube changes.
- **Manual**: User controls updates; auto-checks can be disabled.

---

## 4. Staging, Verification, and Atomic Swap Algorithm

```mermaid
sequenceDiagram
    autonumber
    participant Client as Package Manager
    participant GitHub as GitHub Releases API
    participant Staging as files/packages/staging/
    participant Active as files/packages/active/
    participant Backup as files/packages/backup/

    Client->>GitHub: Check latest release for current ABI (arm64-v8a)
    GitHub-->>Client: Asset URL + SHA-256 Checksum
    Client->>Staging: Download asset archive to staging
    Client->>Staging: Calculate SHA-256 and compare with manifest
    alt Checksum Mismatch
        Client->>Staging: Delete staged file & abort
    else Checksum Valid
        Client->>Staging: Unpack & chmod +x binaries
        Client->>Staging: Run smoke self-test (`--version`)
        Client->>Backup: Move current `active/` to `backup/`
        Client->>Active: Atomically rename `staging/` to `active/`
        alt Self-test on new active fails
            Client->>Active: Swap back `backup/` to `active/` (Rollback)
        else Self-test succeeds
            Client->>Backup: Purge old backup & notify UI
        end
    end
```
