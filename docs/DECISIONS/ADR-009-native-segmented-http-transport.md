# ADR-009: Native Segmented HTTP Transport Behind `DownloadForegroundService`

## Status
Accepted

## Context
ADR-008 introduced `packages/download_engine` (planner, scheduler, atomic task store) but the only transport that actually moved bytes was `yt-dlp`. That works for media pages and extractors, but it is a poor fit for plain large files:

- `yt-dlp` treats a direct URL as a single-stream download; it does not split a 4 GB ISO into parallel byte ranges.
- Resume after an app kill, a network drop or a user pause is limited to whatever the extractor decides to keep.
- Servers expose `Accept-Ranges: bytes` and `Content-Length` for ordinary files, so the information needed for real segmentation is available and unused.

The app also needs a native owner for this work: Android kills Flutter's process while the activity is gone, so the queue and the transport must live in the same `ForegroundService` that already hosts `yt-dlp` runs.

Constraints: no new dependencies (no OkHttp), `minSdk 24`, scoped storage via the existing `DownloadStorageManager`, URL policy from `AGENTS.md` (no `file://`, loopback, link-local or metadata endpoints), and every feature must be covered by automated tests.

## Decision
1. **Transport is `HttpURLConnection`**, in `android/app/src/main/kotlin/dev/meteora/meteora/direct/`:
   - `SegmentedHttpDownloader.probe()` sends `Range: bytes=0-0` to learn length, `Accept-Ranges`, `ETag`, and the filename (`Content-Disposition`, falling back to the URL leaf and MIME). A `416` triggers one re-probe without `Range`; a `200` means the server ignored ranges.
   - Known length + range support + `maxSegments > 1` → N contiguous ranges written **in parallel** to one pre-sized `.part` file with positional `FileChannel` writes (`WRITE` only, no truncating `rw`), so ranges never overwrite each other and no sparse-file guesswork is needed.
   - `Accept-Encoding: identity` and `If-Range: <etag>` so a revalidated resume cannot splice two different versions of a file together.
   - Redirects are followed manually (max 5), and **every hop is re-validated** by `DirectUrlGuard`, so a bucket cannot redirect the service into the loopback interface or a cloud metadata endpoint.
   - Unknown length, `maxSegments == 1`, or a server that ignores `Range` → sequential stream to the same `.part` file.
2. **Resume currency is per-range progress, persisted.** Each `DirectSegment` stores `start`, `end`, `downloaded`, `completed` in the task JSON (atomic tmp + rename + fsync in `DirectDownloadStore`). On a fresh attempt `probe()` runs first: if the server still reports the same length, the stored ranges are kept and only unfinished ranges are requested, starting at their own offset. A changed length (re-encoded file) discards the ranges and restarts, which is the only safe option.
3. **Retry/backoff per range.** `IOException`/`5xx` retries with `500 ms * 2^(n-1)` plus jitter, up to 5 attempts, and a range is never considered done until its declared byte count has landed. `abort()` disconnects the live sockets so pause/cancel takes effect within one read timeout instead of waiting for the whole range.
4. **Queue and scheduling live natively** (`DirectDownloadQueue`) with `SchedulerPolicy(maxConcurrent = 3, maxPerHost = 1)`, mirroring the Dart `DownloadScheduler` so the app and service agree on visible behaviour. `RUNNING` tasks load back as `PAUSED`; a corrupt task file is quarantined as `.corrupt` rather than throwing away the queue.
5. **Routing stays a policy, not a hard-coded branch.** `DirectDownloadPolicy` (`packages/download_engine`) decides direct vs extractor: extractor hosts, and HTML/HLS/DASH content types or `.m3u8`/`.mpd`/`.html` URLs go to `yt-dlp`; unambiguous file extensions (`mp4`, `zip`, `apk`, `pdf`, ...), `application/octet-stream` and media MIME types go direct. Anything ambiguous keeps the old behaviour, because a wrong direct download produces a saved HTML error page.
6. **Dart is a thin façade.** `NativeDirectDownloadEngine` (`lib/services/direct_download_bridge.dart`) implements the existing `DownloadEngine` interface over `MethodChannel dev.meteora/engine`; `DownloadStateManager` creates the persisted task row first and passes its id to the service (`enqueueWithId`), so progress events always find a row. Cookies/UA/referer come from `getWebViewAuthContext` and are re-validated natively.
7. **Publication is unchanged.** The finished `.part` is renamed to its effective filename and handed to `DownloadStorageManager.publishFile`, so MediaStore/SAF rules, the `Download` default and the external-player flow keep working exactly as they do for `yt-dlp` output.
8. **Probe requests retry like ranges.** Writing the end-to-end test exposed that a transient `503` on the very first request failed the download before any byte moved; the probe now shares the retry/backoff policy.

## Consequences
### Positive
- Large direct files download in parallel ranges, survive process death, and resume from the last completed byte range instead of restarting.
- The Download tab gains real pause/resume for direct tasks (yt-dlp runs remain cancel/retry only, which is the extractor's limit).
- Nothing new ships in the APK: `HttpURLConnection`, `FileChannel` and `org.json` are platform APIs.
- The transport is testable on the JVM: `SegmentedHttpDownloaderTest` runs it against a real socket server covering ranges, resume after a failed range, retry, `200` fallback and abort; `DirectTransportTest` covers planning, URL guard and filename parsing.

### Negative
- Range semantics depend on the origin server. A CDN that ignores `Range`, strips `Content-Length` or rotates `ETag` drops to a single stream; the fallback is correct but not faster.
- A pause during the sequential fallback loses that stream's progress, because only range-based progress is persisted.
- The scheduler exists twice (Dart for UI-visible grouping, Kotlin for enforcement). Both caps must be kept in sync by hand; a shared codegen step would remove that risk but is not worth it for two numbers today.
- LAN addresses (`10/8`, `172.16/12`, `192.168/16`) are deliberately allowed so a NAS can serve files; only loopback, link-local and metadata hosts are blocked (see ADR-008's threat model and `DirectUrlGuard`). An app on the same LAN can therefore be reached through a user-supplied URL.
- MediaStore/SAF publication, notification throttling and pause-across-process-death are verified only by compilation and unit tests so far; they need an on-device run against a real CDN.
