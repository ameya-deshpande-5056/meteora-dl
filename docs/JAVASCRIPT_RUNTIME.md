# JavaScript Runtime & EJS Challenge Solving (Deno & QuickJS-NG)

## 1. The Challenge Landscape
Modern streaming platforms (particularly YouTube) employ dynamic obfuscation scripts that update continuously. Two prominent protection mechanisms are:
1. **Signature Deciphering**: Player JavaScript calculates stream decryption tokens.
2. **Dynamic Throttling (`n` parameter)**: A challenge function calculates an `n` token that YouTube servers verify before allowing high-speed stream downloads. If unsolved or calculated incorrectly, streaming speeds are throttled to unusable levels (~40-60 KB/s).

Historically, yt-dlp extracted these regexes and interpreted them in Python. To maintain reliability against increasingly complex code transformations, yt-dlp introduced **EJS (External JavaScript)** via the `yt-dlp-ejs` component package, offloading execution to an external JavaScript runtime.

---

## 2. Runtime Evaluation: Deno vs QuickJS-NG

| Feature / Metric | Deno (Primary) | QuickJS-NG (Lightweight Alternative) |
| :--- | :--- | :--- |
| **Engine Core** | V8 (Rust / C++) | QuickJS ES2023 (Pure C) |
| **Binary Size** | ~70 - 90 MB | **~1.2 MB** |
| **Startup Latency** | ~40 - 80 ms | **~3 - 8 ms** |
| **RAM Footprint** | ~35 - 50 MB | **~4 - 8 MB** |
| **EJS Compatibility** | 100% (Upstream Default) | High (Fully supported by yt-dlp with `qjs`) |
| **Android ARM64 Build** | Bionic / musl port required | **Native NDK C clang compiles out-of-the-box** |
| **Sandboxing** | Strict permission flags (`--no-net`, `--no-read`) | Embedded in-process sandboxing |

---

## 3. Configuration in yt-dlp

Meteora passes the selected runtime to `yt-dlp`:

### Using Deno:
```bash
yt-dlp --js-runtimes "deno:/data/user/0/dev.meteora/files/packages/active/deno/deno" \
       --remote-components ejs:github
```

### Using QuickJS-NG (Embedded Default in `youtubedl-android` + `NativeEngineManager`):
```bash
yt-dlp --js-runtimes "quickjs:/path/to/libqjs.so" \
       --cache-dir "/data/user/0/<app_id>/cache/ytdlp-cache" \
       --remote-components ejs:github
```
> Note: `youtubedl-android` (`0.18.1`) injects `--no-cache-dir` unless `--cache-dir` is explicitly provided. `NativeEngineManager` sets `--cache-dir` to `cacheDir/ytdlp-cache` and adds `--remote-components ejs:github` on every execution so updated `yt-dlp` releases can fetch and reuse current EJS solver scripts (`yt.solver.lib.min.js`) rather than falling back to older bundled scripts and failing `n`-challenge solving.

---

## 4. Anti-Bot and Access Boundary Clarification
> [!IMPORTANT]
> A JavaScript runtime solely executes client player code to calculate signature and `n` tokens. It **does not** bypass CAPTCHAs, Cloudflare Turnstile, proof-of-work gates, geoblocks, or private account authentication. Meteora treats authentication blocks as terminal errors and surfaces friendly error alerts to the user.
