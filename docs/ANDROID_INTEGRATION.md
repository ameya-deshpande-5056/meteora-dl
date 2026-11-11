# Android Native Integration Guide

## 1. Overview
The Android native integration in `android/` handles high-privilege OS interactions that require native APIs:
- Background process lifecycle via `DownloadForegroundService` (with retries and `HTTP 403` / `HTTP 429` recovery).
- Public `Downloads` (`MediaStore.Downloads`) and Storage Access Framework (`ACTION_OPEN_DOCUMENT_TREE`) publishing via `DownloadStorageManager`.
- Embedded `yt-dlp` / CPython / QuickJS / FFmpeg execution via `NativeEngineManager` (`youtubedl-android`) and `SafeProcessExecutor`.
- External player launch via `Intent.ACTION_VIEW` chooser + `FileProvider`.

---

## 2. DownloadForegroundService Architecture

### Manifest Declaration
```xml
<service
    android:name=".service.DownloadForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

### Required Permissions
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
```
On first launch (`FirstLaunchSetupDialog`), `MainActivity` requests the active API-level subset of runtime permissions (`POST_NOTIFICATIONS`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` on Android 13+; `READ_EXTERNAL_STORAGE` on Android 11–12; `READ/WRITE_EXTERNAL_STORAGE` on Android 7–10) via `requestPermissions`.

### Lifecycle Management & WakeLocks
1. **Service Promotion**:
   When a download initiates, `startForeground()` is called immediately with a persistent notification (`PRIORITY_LOW` or `PRIORITY_DEFAULT`).
2. **Power Constraints**:
   - `PowerManager.PARTIAL_WAKE_LOCK` is acquired with a safety timeout (e.g. 2 hours max per task).
   - `WifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "Meteora:Download")` prevents Wi-Fi throttling during active downloads.
3. **Task Completion**:
   When all tasks finish or are paused, the WakeLock is released, and the service transitions out of the foreground via `stopForeground(STOP_FOREGROUND_REMOVE)` or shuts down.

---

## 3. Persistent State & Recovery

To survive OEM battery kills or OS low-memory process termination:
- Every active task is committed to the local database with:
  - `taskId`, `url`, `selectedFormat`, `downloadedBytes`, `totalBytes`, `filePath`, `status`.
- `yt-dlp` natively handles resume using `-c` (`--continue`). If the process was terminated midway, it resumes downloading the `.part` file without re-fetching existing bytes.
- When `DownloadForegroundService` boots (or via `BOOT_COMPLETED` receiver if configured), pending/interrupted downloads can be re-queued with exponential backoff.

---

## 4. Scoped Storage, Public Downloads & Custom SAF Folders

Modern Android (Android 10–15) isolates direct filesystem writes. [`DownloadStorageManager`](file:///home/ameya/meteora-dl/android/app/src/main/kotlin/dev/meteora/meteora/storage/DownloadStorageManager.kt) manages user-accessible storage cleanly without `MANAGE_EXTERNAL_STORAGE`:

1. **Staging**: `DownloadForegroundService` downloads and muxes into an isolated per-task staging folder (`context.filesDir/staging/<taskId>`), cleaning it up in `finally` after publishing.
2. **Custom Folder via Storage Access Framework (SAF)**:
   - Users can choose any accessible directory during first-launch setup or in Settings (`pickDownloadDirectory` -> `Intent.ACTION_OPEN_DOCUMENT_TREE`).
   - `MainActivity` calls `setCustomDownloadDirectory(treeUri)`, taking persistable read/write URI permissions (`takePersistableUriPermission`) and writing outputs via `DocumentsContract.createDocument(...)` (avoiding duplicate extensions added by `ExternalStorageProvider`).
3. **Default Public Downloads Publishing**:
   - When no custom folder is configured (or if a persisted SAF grant was revoked), files publish to Android's public **Download** folder (`Environment.DIRECTORY_DOWNLOADS`):
     ```kotlin
     val downloadsUri = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
     val values = ContentValues().apply {
         put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
         put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
         put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
         put(MediaStore.MediaColumns.IS_PENDING, 1)
     }
     val itemUri = resolver.insert(downloadsUri, values)
     // Copy bytes from staging -> openOutputStream(itemUri), clear IS_PENDING, and run MediaScannerConnection.scanFile()
     ```
   - On Android 9 and below (`Build.VERSION.SDK_INT < Build.VERSION_CODES.Q`), files are written to `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)` with collision-free naming and indexed via `MediaScannerConnection.scanFile`.

---

## 5. Runtime Defaults, Error Recovery & External Playback

- **EJS Cache & IPv4 Consistency (`NativeEngineManager`)**: Initializes `YoutubeDL` and `FFmpeg` once on `Dispatchers.IO`, creates `cacheDir/ytdlp-cache`, and injects `--cache-dir <path>` (overriding `youtubedl-android`'s `--no-cache-dir`), `--remote-components ejs:github`, and `--force-ipv4` (when an active non-loopback `Inet4Address` exists).
- **Resilient Download Recovery (`DownloadForegroundService`)**:
  - Adds `--retries 5`, `--fragment-retries 10`, and `--extractor-retries 3`.
  - On `HTTP Error 403` / `unable to download video data`, deletes partial `.part`/`.ytdl` staging files and retries with `--extractor-args youtube:player_client=tv,android_vr,visionos`, `--force-ipv4`, and mode-appropriate fallback selectors (`bestaudio/best`, `bestvideo+bestaudio/best`, or `bestvideo/best`).
  - On YouTube subtitle rate limiting (`HTTP Error 429` / `timedtext`), retries media downloads without subtitle flags (or reports the rate-limit message for subtitles-only tasks).
- **External Media Player Handoff (`MainActivity.playMedia`)**:
  - Resolves `content://` URIs directly or wraps local file paths via `FileProvider` (`${applicationId}.fileprovider` in `res/xml/file_paths.xml`).
  - Launches `Intent.createChooser(Intent(Intent.ACTION_VIEW), "Open with")` with `FLAG_GRANT_READ_URI_PERMISSION`, `ClipData.newRawUri`, and `<queries>` intent filters for `video/*`, `audio/*`, and `text/*`.
