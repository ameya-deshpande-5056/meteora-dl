# Media Library Package Instructions (`packages/media_library/AGENTS.md`)

## Responsibilities
`packages/media_library` is responsible for organizing, indexing, querying, and managing downloaded offline media:
1. **Metadata Inspection**:
   - Parses FFprobe JSON output to extract duration, resolution, video codec, audio channels, sampling rate, bit depth, and container tags.
2. **Persistent Storage (Drift/SQLite)**:
   - Stores media records, file paths, thumbnails, media types (video/audio), collections, and tags.
   - Provides reactive streams (`Watch`) for UI consumption in Flutter.
3. **File Management**:
   - Verifies file integrity on disk.
   - Deletes media records and corresponding physical files cleanly.
   - Handles file renaming and sharing.
4. **Playback State & History**:
   - Tracks playback positions (resume playback) and play counts.
