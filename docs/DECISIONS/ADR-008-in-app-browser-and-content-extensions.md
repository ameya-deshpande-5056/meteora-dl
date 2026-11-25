# ADR-008: In-App Browser, Segmented Download Engine Package & WebView-Adapted Content Extensions

## Status
Accepted

## Context
1. **Browser auth context on Android**: On desktop, qtIDM receives cookies, user agent, referer and request headers from Chrome/Firefox through Native Messaging. Android has no equivalent channel: an app cannot read another browser's cookie jar, user agent overrides or request headers. Reproducing "download this link exactly as the browser would" therefore requires a browser inside the app.
2. **Download manager completeness**: qtIDM's engine is a segmented, resumable, queue-aware HTTP downloader (segment planner, sparse `.part` staging, retry/backoff, per-host concurrency). Meteora currently downloads through `yt-dlp` only, so media pages work well but plain large files have no segmented/resumable path.
3. **Content extensions**: uBlock Origin, Dark Reader and Violentmonkey are WebExtension-based. Android WebView has no `webRequest` blocking API and no extension runtime.
4. **Motion budget**: the floating dock previously animated a per-tab capsule, so selection looked like a cross-fade rather than something physically moving, and every tab item rebuilt its own decoration during the transition.

## Decision
1. **In-app browser (`packages/browser`)**: `WebViewScreen` wraps `webview_flutter` and is the app's single source of first-party auth context. `BrowserAuthContext` carries cookies/UA/referer/headers from that WebView, and `EngineDownloadBridge` converts it into a `DownloadRequest` (http/https only). Because WebView exposes no response-header hook, `mediaCaptureScript` reports `<video>`/`<audio>` sources and resource-timing entries from inside the page; `MediaCandidateCollector` filters HLS/DASH segments, de-duplicates and caps the list, and `MediaProbe` classifies results. Captured media is handed to the existing Home extraction flow (yt-dlp) rather than a second, competing downloader.
2. **Download engine package (`packages/download_engine`)**: domain models (`DownloadRequest`, `DownloadTask`, `Segment`, `DownloadStatus`), a `SegmentPlanner`, a `DownloadScheduler` enforcing global and per-host caps, and a crash-safe `DownloadTaskStore` (atomic temp-file rename, corrupt-queue quarantine, interrupted `running` tasks demoted to `paused` so they resume instead of leaking). The `DownloadEngine` interface keeps the transport (plain HTTP vs. yt-dlp) an implementation detail.
3. **Content extensions (`packages/content_extensions`)**: `ContentBlocker` adapts the three extensions' *behaviour* to WebView — cosmetic filters become injected CSS, Dark Reader settings become a `filter` declaration, userscripts are matched by URL pattern and injected as JS. No WebExtension API surface is claimed; GeckoView would be required for real extension parity.
4. **Tab switcher (`lib/widgets/adaptive_scaffold.dart`)**: one shared indicator (`AnimatedPositioned` + tinted pill) travels between destinations instead of per-item capsules. The indicator never blurs while moving (blur stays on the static glass dock), respects `MediaQuery.disableAnimations`, and is driven by the existing `AppMotion.spring`/`medium` tokens.

## Consequences
### Positive
- Downloads started from the built-in browser reuse the exact session the user logged in with, which is impossible with an external browser on Android.
- Segment/queue/resume logic is testable in pure Dart before any native transport is written.
- Media discovered while browsing lands in the existing format selector, so the app never silently picks a quality.
- The dock animates a single element, so selection costs one moving layer instead of N rebuilding items.

### Negative
- WebView capture is heuristic: it sees DOM/timing data, not response headers, so some players that fetch through workers may not be detected.
- Content filtering cannot block requests the way uBlock Origin does in a real browser; it hides elements and rewrites styles after load.
- At the time of this ADR `yt-dlp` was the only executing transport; the segmented HTTP transport was added later in ADR-009 and now handles plain files behind `DownloadForegroundService`.
