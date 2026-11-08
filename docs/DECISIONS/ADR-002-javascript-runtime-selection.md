# ADR-002: Dual JavaScript Runtime Strategy (Deno & QuickJS-NG)

## Status
Accepted

## Context
yt-dlp offloads dynamic challenge solving (such as YouTube's `n`-parameter throttling function and signature deciphering) to an external JavaScript runtime using the `yt-dlp-ejs` component. Upstream yt-dlp recommends **Deno** as the primary runtime. However, standard Deno binaries target glibc and have a large binary footprint (~70-90MB), whereas Android devices use Bionic libc and benefit from lean footprints and minimal memory overhead.

## Decision
We implement a dual-engine architecture:
1. **Deno (Primary/Recommended)**: Supported using Android Bionic / musl builds for 100% upstream feature parity and compatibility with all `yt-dlp-ejs` scripts.
2. **QuickJS-NG (Lightweight Alternative)**: Supported natively via Android NDK compilation. QuickJS-NG compiles into a ~1.2MB binary, starts in <5ms, uses <8MB RAM, and is fully recognized by `yt-dlp` using `--js-runtimes quickjs:<path>`.
3. Users can toggle between Deno and QuickJS-NG in Settings, with fallback to QuickJS-NG if Deno is not present.

## Consequences
### Positive
- Guaranteed compatibility with complex EJS challenges via Deno.
- Extreme lightweight option via QuickJS-NG for resource-constrained or storage-limited devices.
- Zero dependency on desktop Linux binaries.

### Negative
- Requires maintaining update endpoints and validation logic for both runtimes.
