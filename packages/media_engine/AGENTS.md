# Media Engine Package Instructions (`packages/media_engine/AGENTS.md`)

## Responsibilities
`packages/media_engine` is a pure Dart domain package responsible for:
1. Parsing yt-dlp JSON extraction output into typed models (`MediaInfo`, `FormatInfo`, `StreamType`, `AudioTrack`, `SubtitleTrack`).
2. **Intelligent Format Selection Algorithm**:
   - Compares available video and audio streams against device hardware capabilities.
   - Evaluates display resolution (e.g., limits 4K downloads if display is 1080p and data is metered).
   - Identifies hardware-supported video codecs (AV1, VP9, H.265/HEVC, H.264/AVC) and audio codecs (Opus, AAC).
   - Balances file size vs visual quality and favors direct container muxing (`-c copy`) without re-encoding.
3. Building execution requests for yt-dlp:
   - CLI parameter generation (format strings `-f`, `--merge-output-format`, `--js-runtimes`, `--extractor-args`).

## Testing Mandate
- Provide unit tests for:
  - JSON parsing of complex YouTube, Twitter, Reddit, and TikTok metadata payloads.
  - Intelligent format selection decisions across device profiles (e.g. low-end device on mobile data vs high-end device on Wi-Fi).
  - Stream pairing (video-only + audio-only compatibility).
