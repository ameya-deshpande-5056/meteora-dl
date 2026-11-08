# Android Subsystem Instructions (`android/AGENTS.md`)

## Responsibilities
The `android/` subsystem contains the Android-native integration layer written in **Kotlin**. It is responsible for:
1. Native process execution of `yt-dlp` and JavaScript engines (`deno`, `quickjs-ng`).
2. Long-running background downloads via `DownloadForegroundService`.
3. Persistent foreground notification with live progress, pause, resume, and cancel actions.
4. Scoped Storage / MediaStore API integration for writing media to public Movies/Music folders.
5. Android Media3 (ExoPlayer) playback bridge and hardware codec capability detection.

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
