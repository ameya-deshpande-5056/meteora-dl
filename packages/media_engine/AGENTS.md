# Media Engine Package Instructions (`packages/media_engine/AGENTS.md`)

## Responsibilities
`packages/media_engine` is a pure Dart domain package responsible for:
1. Parsing yt-dlp JSON extraction output into typed models (`MediaInfo`, `FormatInfo`, `StreamType`, `SubtitleTrackInfo`).
2. Device capability modelling (`DeviceCapabilities`).
   - `DeviceCapabilities` describes the hardware and network so the UI and native layer can report what a device supports (Settings → Hardware Diagnostics).
   - It is **not** used to pick formats automatically. There is no automatic quality or format chooser in this package; the user's explicit selection in the Home screen is what is downloaded.
3. Building execution requests for yt-dlp:
   - `SimpleDownloadCommandBuilder` produces the argument vectors the app actually runs (format strings `-f`, subtitle flags, extract-audio `-x`, `--skip-download`).
   - `CommandBuilder` produces argument vectors for standalone Python hosts (`--js-runtimes`, `--merge-output-format`, `--ffmpeg-location`).

## Testing Mandate
- Provide unit tests for:
  - JSON parsing of complex YouTube, Twitter, Reddit, and TikTok metadata payloads.
  - Format and subtitle label rendering (`videoSelectionLabel`, `audioSelectionLabel`, `SubtitleTrackInfo.displayLabel`).
  - Command construction for every `DownloadMode`, including subtitle and audio-only paths, and `CommandBuilder` extraction/download argument vectors.
