# Package Manager Instructions (`packages/package_manager/AGENTS.md`)

## Responsibilities
`packages/package_manager` handles in-app, independent lifecycle management and updates for all external binary and script packages:
- `yt-dlp` (Core extractor)
- `yt-dlp-ejs` (YouTube JavaScript challenge solver bundle)
- `deno` (Primary JavaScript runtime)
- `quickjs-ng` (Lightweight fallback JavaScript runtime)
- `ffmpeg` & `ffprobe` (Media merger and metadata inspector)

## Architectural Lifecycle & Safety Rules
1. **GitHub Release Discovery**:
   - Query official GitHub releases API for latest tags, pre-releases, and assets.
   - Support channels: **Stable**, **Nightly**, and **Manual**.
2. **ABI Matching**:
   - Detect device ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and download matching asset archives.
3. **Cryptographic Validation**:
   - Download SHA-256 checksum files when available.
   - Compute hash of downloaded payload before moving to staging.
4. **Staging & Atomic Replacement**:
   - Download directly into a staging directory: `files/packages/staging/<package_name>/`.
   - Validate executable permissions (`chmod +x`).
   - Move current active package to `files/packages/backup/<package_name>/`.
   - Atomically rename staging to active: `files/packages/active/<package_name>/`.
5. **Rollback Strategy**:
   - If self-test fails after swap, restore from backup directory and flag error.
