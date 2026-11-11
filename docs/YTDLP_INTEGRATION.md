# yt-dlp Integration & Command Execution

## 1. Overview
`yt-dlp` is the core extraction and download workhorse in Meteora. Because yt-dlp is implemented in Python, executing it on Android requires either:
1. An embedded Python runtime (`libpython.so` with `youtubedl-android` wrapper or Chaquopy / Python C API).
2. A standalone statically-linked Python 3 binary on Android.

---

## 2. Command Invocation Protocol

### Security: Strictly No Shell String Interpolation
Invoking commands via shell string concatenation (`Runtime.getRuntime().exec("python yt-dlp " + url)`) exposes the system to command injection through malicious URLs or metadata parameters.

Meteora executes all processes using strict `ProcessBuilder` argument vectors:

```kotlin
val command = mutableListOf<String>().apply {
    add(pythonBinaryPath)
    add(ytdlpScriptPath)
    add("--no-playlist")
    add("--dump-single-json")
    add("--no-warnings")
    add("--js-runtimes")
    add("deno:$denoBinaryPath")
    add("--")
    add(sanitizedUrl)
}

val process = ProcessBuilder(command)
    .directory(workingDir)
    .redirectErrorStream(true)
    .start()
```

---

## 3. Streaming Progress Parsing

yt-dlp outputs download progress to stdout in a format that can be parsed line-by-line:
`[download]  45.2% of  120.50MiB at   5.20MiB/s ETA 00:12`

Meteora uses regular expressions to capture real-time download metrics:
```kotlin
val progressRegex = Regex("""\[download\]\s+([\d.]+)%\s+of\s+~?([\d.]+)(\w+)\s+at\s+([\d.]+)(\w+/s)\s+ETA\s+([\d:]+)""")
```
Captured metrics are mapped to typed `DownloadProgressEvent` objects and streamed to Flutter through an `EventChannel`.

---

## 4. Multi-Stream Merging Arguments

For separate video and audio streams:
```
-f <video_id>+<audio_id>
--ffmpeg-location /data/user/0/dev.meteora/files/packages/active/ffmpeg/ffmpeg
--merge-output-format mp4
--postprocessor-args "ffmpeg:-c copy"
```
This forces FFmpeg to mux without transcoding, saving CPU time, battery, and preventing generation loss.

---

## 5. Runtime Defaults, Download Modes & Error Recovery

- **Runtime Defaults (`NativeEngineManager.applyRuntimeDefaults`)**:
  - Injects `--cache-dir <app_cache>/ytdlp-cache` (overriding `youtubedl-android`'s `--no-cache-dir` fallback so EJS challenge scripts persist across invocations).
  - Enables `--remote-components ejs:github` when not explicitly overridden, ensuring updated `yt-dlp` versions can download current solver bundles (`yt.solver.lib.min.js`).
  - Adds `--force-ipv4` when an active non-loopback IPv4 interface is detected (`hasActiveIpv4Interface()`), preventing IPv4/IPv6 dual-stack 403 mismatches on `googlevideo.com`.
- **Simple Download Modes (`SimpleDownloadCommandBuilder`)**:
  - Builds typed argument lists for `Video + Audio`, `Video Only`, `Audio Only` (`-x`), and `Subtitles Only` (`--skip-download`) with optional creator (`--write-subs`), auto-caption (`--write-auto-subs`), `--embed-subs`, `--sub-format`, and `--sleep-subtitles 2`.
- **Resilient Retry & Fallback Recovery (`DownloadForegroundService`)**:
  - Configures `--retries 5`, `--fragment-retries 10`, and `--extractor-retries 3`.
  - **403 Fallback**: On `HTTP Error 403` / `unable to download video data`, deletes `.part` and `.ytdl` staging files, adapts `-f <id>` to `bestaudio/best`, `bestvideo+bestaudio/best`, or `bestvideo/best`, adds `--extractor-args youtube:player_client=tv,android_vr,visionos` and `--force-ipv4`, and retries.
  - **429 Subtitle Fallback**: If YouTube `timedtext` rate-limits subtitles during a media download, strips subtitle flags (`stripSubtitleArgs`) and continues saving the media stream.
