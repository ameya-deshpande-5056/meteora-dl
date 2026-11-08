# Android Native Integration Guide

## 1. Overview
The Android native integration in `android/` handles high-privilege OS interactions that require native APIs:
- Background process lifecycle via `DownloadForegroundService`.
- MediaStore API integration for Scoped Storage compliance.
- Direct execution of binary processes (`yt-dlp`, `deno`, `quickjs-ng`, `ffmpeg`).
- ExoPlayer / Media3 platform view rendering.

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
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

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

## 4. Scoped Storage & MediaStore Insertion

Modern Android (Android 10 - 15) strictly isolates application storage. To make downloaded media visible in the user's gallery and music players:

1. **Staging**: Downloads are written to app-specific external storage:
   `context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)`
2. **Publishing**: Upon successful completion and FFmpeg muxing, the file is inserted into Android MediaStore:
   ```kotlin
   val values = ContentValues().apply {
       put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
       put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
       put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/Meteora")
       put(MediaStore.MediaColumns.IS_PENDING, 1)
   }
   val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
   // Stream bytes from internal storage to uri via openOutputStream()
   values.clear()
   values.put(MediaStore.MediaColumns.IS_PENDING, 0)
   contentResolver.update(uri, values, null, null)
   ```
   This ensures compatibility across Android 10 (Q) through Android 15 (Vanilla Ice Cream) without needing legacy `WRITE_EXTERNAL_STORAGE`.
