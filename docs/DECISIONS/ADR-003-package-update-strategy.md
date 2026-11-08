# ADR-003: Independent Binary Package Updates and Atomic Staging

## Status
Accepted

## Context
Upstream video extractors and challenge solvers (`yt-dlp`, `yt-dlp-ejs`) change frequently to counter platform alterations. Relying on full application APK releases through app stores creates unacceptable latency and user frustration when extractors break.

## Decision
Implement an in-app Package Update Manager that directly checks official GitHub release APIs for `yt-dlp`, `yt-dlp-ejs`, `deno`, `quickjs-ng`, and `ffmpeg/ffprobe`.
Updates execute through a three-tier directory pattern:
- `files/packages/staging/<pkg>`: Initial download and SHA-256 validation.
- `files/packages/backup/<pkg>`: Preservation of previous working binary.
- `files/packages/active/<pkg>`: The live executable location.

The swap from `staging` to `active` is performed atomically via directory rename. If a post-update smoke test (`--version`) fails, the manager automatically rolls back to `backup`.

## Consequences
### Positive
- App survives extractor breakages without requiring a new APK release or store approval.
- Zero downtime: active binaries are replaced in a fraction of a second.
- Corruption safety: failed or partial downloads never overwrite the working engine.

### Negative
- Requires maintaining network logic, parsing GitHub release payloads, and managing Android file permissions (`chmod`).
