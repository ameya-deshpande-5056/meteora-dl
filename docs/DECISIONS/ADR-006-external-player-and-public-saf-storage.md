# ADR-006: External Media Player Integration & Accessible Public/SAF Download Storage

## Status
Accepted (supersedes the Media3 player and `/Movies/Meteora` storage assumptions in ADR-001)

## Context
Bundling `androidx.media3:media3-exoplayer` and `media3-ui` inside the APK added dependency weight and duplicated playback features already handled better by dedicated Android players (such as VLC and mpv) installed on users' devices.

Additionally, storing finished downloads only inside app-managed `Movies/Meteora` or `Music/Meteora` folders limited user visibility and flexibility across file managers, browsers, and custom directories (e.g., SD cards or user-chosen folders). Users also needed a guided first-launch prompt to select their preferred download folder and grant runtime permissions cleanly.

## Decision
1. **External Player Handoff (`Intent.ACTION_VIEW` + `FileProvider`)**:
   - Removed `androidx.media3:media3-exoplayer`, `androidx.media3:media3-ui`, `PlayerActivity.kt`, and `activity_player.xml`.
   - Configured `androidx.core.content.FileProvider` (`${applicationId}.fileprovider` in `res/xml/file_paths.xml`) and `<queries>` intent filters (`video/*`, `audio/*`, `text/*`) in `AndroidManifest.xml`.
   - `MainActivity.playMedia` launches `Intent.createChooser(Intent(Intent.ACTION_VIEW), "Open with")` with `FLAG_GRANT_READ_URI_PERMISSION`, `ClipData.newRawUri`, and MIME resolution via `DownloadStorageManager.resolveOpenMimeType`.
2. **Accessible Public Downloads & Storage Access Framework (`DownloadStorageManager`)**:
   - Downloads stage inside app-private `filesDir/staging/<taskId>` and are published on completion by `DownloadStorageManager.publishFile`.
   - Default destination publishes to the public system **Download** directory (`MediaStore.Downloads` with `Environment.DIRECTORY_DOWNLOADS` on Android 10+, or `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)` on Android 9 and below) and runs `MediaScannerConnection.scanFile`.
   - Users can choose any custom folder via `Intent.ACTION_OPEN_DOCUMENT_TREE` (with `takePersistableUriPermission` persisted in `SharedPreferences`) or reset back to the default folder from Settings.
3. **Guided First-Launch Onboarding (`FirstLaunchSetupDialog`)**:
   - On initial install (`first_launch_setup_done` in SQLite `app_settings`), `MainNavigationScreen` displays `FirstLaunchSetupDialog` so the user can configure their download folder and grant required runtime permissions (`POST_NOTIFICATIONS`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, or scoped legacy storage permissions on older Android versions).

## Consequences
### Positive
- Smaller APK footprint and zero custom video-player maintenance burden.
- Downloaded videos, audio tracks, and subtitles work immediately in VLC, mpv, system gallery/music apps, and user-chosen folders.
- Clear first-run permission and storage UX compliant with Android 10–15 Scoped Storage (no `MANAGE_EXTERNAL_STORAGE`).

### Negative
- Playback experience depends on the user having a compatible external media player installed (handled gracefully by returning `false` from `playMedia` when no activity handles the intent).
- SAF `DocumentsContract.createDocument` requires MIME workaround handling (`application/x-meteora-media`) when `ExternalStorageProvider` would otherwise append duplicate extensions.
