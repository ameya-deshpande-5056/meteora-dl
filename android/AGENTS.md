# Android Subsystem Instructions (`android/AGENTS.md`)

## Responsibilities
The `android/` subsystem contains the Android-native integration layer written in **Kotlin**. It is responsible for:
1. Native process execution of `yt-dlp`, embedded CPython 3 (`youtubedl-android`), and JavaScript engines (`deno`, `quickjs-ng`), with cached `ejs:github` components via `NativeEngineManager`.
2. Long-running background downloads via `DownloadForegroundService` with retries and automatic `HTTP 403` / `HTTP 429` fallback recovery.
3. Persistent foreground notification with live progress, speed/ETA, and cancel actions.
4. Scoped Storage integration via `DownloadStorageManager`: publishes to Android's public `Downloads` directory (`MediaStore.Downloads` / `Environment.DIRECTORY_DOWNLOADS`) or user-chosen SAF (`ACTION_OPEN_DOCUMENT_TREE`) folders.
5. External media player handoff (`Intent.ACTION_VIEW` chooser + `FileProvider`) and hardware codec capability detection (`DeviceCapabilityDetector`).

## Engineering Standards
- **Kotlin 2.0+**: Idiomatic Kotlin with Coroutines and StateFlow.
- **Process Execution**:
  - Always execute external binaries using `ProcessBuilder(commandList)` or native C POSIX fork/exec via JNI.
  - Set required environment variables: `PATH`, `PYTHONPATH`, `TMPDIR`.
  - Redirect stdout and stderr safely; avoid thread deadlocks when draining output buffers.
  - Never construct commands using `sh -c` or shell concatenation.
- **Foreground Service**:
  - Must declare `android:foregroundServiceType="dataSync"` in `AndroidManifest.xml`.
  - Handle Android 14+ foreground service requirements (notification permission `POST_NOTIFICATIONS`, foreground service permission).
  - Acquire `PARTIAL_WAKE_LOCK` and `WifiLock` during active transfers, and release them promptly when tasks pause or complete.
- **State Recovery**:
  - Save transfer resume tokens and active task states in SQLite/SharedPreferences to recover seamlessly from process termination.
