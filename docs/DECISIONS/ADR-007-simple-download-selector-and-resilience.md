# ADR-007: Simple Download Mode/Codec/Subtitle Selector & YouTube 403/429 Resilience

## Status
Accepted

## Context
1. **Selector UX**: Presenting abstract quality preset cards (`Optimal`, `Maximum`, `Audio`, etc.) hid exact resolution, framerate, codec (`AV1`, `VP9`, `H.265`, `H.264`, `Opus`, `AAC`), bitrate, and subtitle track choices from users who expect direct control over what streams are downloaded.
2. **UI Theme & Surface Feedback**: An inline 4-option segmented theme switcher compressed long labels, and insufficient frosted backdrop treatment hid the Liquid Glass visual identity across chrome surfaces.
3. **YouTube Runtime Failures (`HTTP 403` & `HTTP 429`)**:
   - `youtubedl-android` (`0.18.1`) passes `--no-cache-dir` unless `--cache-dir` is explicitly provided. When `yt-dlp` updates dynamically (e.g., to `2026.10.26`), older bundled EJS scripts fail `n`-challenge solving unless updated remote EJS components (`ejs:github`) can be fetched and cached.
   - Dual-stack IPv4/IPv6 discrepancies between extraction and CDN stream fetches, single player client failures, and YouTube `timedtext` HTTP 429 subtitle rate limits caused mid-download task failures.

## Decision
1. **Simplified Download Selector (`DownloadMode` & `SimpleDownloadCommandBuilder`)**:
   - `HomeScreen` offers four direct download modes (`Video + Audio`, `Video Only`, `Audio Only`, `Subtitles Only`) alongside explicit bottom-sheet pickers for Video Resolution & Codec (single-line badges such as `1080p60`), Audio Bitrate & Codec (two-line ellipsis-free bitrate badges), and multi-select Subtitle Languages (creator + auto-generated captions via `SubtitleTrackInfo`).
   - `SimpleDownloadCommandBuilder` generates typed `yt-dlp` argument lists, adding `--sleep-subtitles 2` when downloading subtitles. `IntelligentFormatSelector` remains available in `packages/media_engine`.
2. **Material 3 Theme Dialog & Frosted Liquid Glass Surfaces**:
   - Replaced the inline segmented button in `SettingsScreen` with a `Theme` row opening a Liquid Glass `Choose theme` dialog (`Follow System`, `Light Mode`, `Dark Mode`, `AMOLED Black`) persisted in SQLite (`app_settings`).
   - Upgraded `LiquidGlassContainer`, `LiquidGlassAppBar`, `LiquidGlassBackground`, and `AdaptiveScaffold` to render `BackdropFilter` frosted blur, directional sheen gradients, and specular rim borders on floating chrome/modals with reduced-motion fallbacks.
3. **Engine Defaults & Automatic Recovery (`NativeEngineManager` & `DownloadForegroundService`)**:
   - `NativeEngineManager` initializes `cacheDir/ytdlp-cache` and applies `--cache-dir`, `--remote-components ejs:github`, and active-interface `--force-ipv4` on every request unless overridden.
   - `DownloadForegroundService` enables retries (`--retries 5`, `--fragment-retries 10`, `--extractor-retries 3`) and implements `executeWithRecovery`:
     - On `HTTP Error 403` / `unable to download video data`, clears `.part`/`.ytdl` staging files, adapts `-f <id>` to `bestaudio/best`, `bestvideo+bestaudio/best`, or `bestvideo/best`, applies `--extractor-args youtube:player_client=tv,android_vr,visionos` + `--force-ipv4`, and retries.
     - On subtitle `timedtext` / HTTP 429 failures during media downloads, strips subtitle flags (`stripSubtitleArgs`) and retries so the media stream still completes.

## Consequences
### Positive
- Users gain transparent control over codecs, resolutions, bitrates, and subtitles without preset guesswork.
- Updated `yt-dlp` releases solve YouTube JS challenges reliably with cached `ejs:github` components and recover automatically from transient `403` / `429` responses.
- Theme selection scales cleanly across all four theme variants and persists across restarts.

### Negative
- Enabling `--remote-components ejs:github` allows `yt-dlp` to fetch and cache updated solver scripts from GitHub when needed.
- On 403 client fallback retries, exact format IDs must relax to best-stream selectors compatible with the fallback client.
