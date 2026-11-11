# Security Architecture & Policies

## 1. Threat Model & Safeguards

| Threat Vector | Potential Impact | Meteora Mitigation Strategy |
| :--- | :--- | :--- |
| **Command Injection via Malicious URL** | Remote Code Execution (RCE) via shell metacharacters (`;&\|` in query params or title). | **Zero Shell Invocation**: `ProcessBuilder` with typed argument lists. URLs are passed directly as distinct array elements after standard scheme and host verification. |
| **Tampered Component Updates** | Supply chain compromise / unauthorized binary replacement. | **Cryptographic Checksumming**: SHA-256 validation against official GitHub releases. Packages are downloaded exclusively over HTTPS directly from authorized GitHub repositories. |
| **Arbitrary Code Execution in JavaScript Engine** | Rogue scripts compromising host files or network. | **Sandboxing**: Deno runs without `--allow-all`, with network disabled by default. QuickJS-NG runs within memory-restricted boundaries without OS shell primitives. |
| **Path Traversal in Media Titles** | Writing outside app directories (`../../../../`). | Filenames are sanitized via `DownloadStorageManager.sanitizeFilename` (stripping path separators, reserved characters, and control bytes), staged in app-private per-task directories, and written only through `MediaStore`, user-granted SAF tree URIs, or scoped `FileProvider` URIs (`res/xml/file_paths.xml`). |
| **Background Battery / Resource Exhaustion** | System throttling, memory kills, device overheat. | Long-running downloads require explicit Foreground Service. WakeLocks are acquired with timeouts and released immediately on completion/pause. |

---

## 2. Permissions Model

Meteora adheres to the principle of least privilege:
- `android.permission.INTERNET` & `ACCESS_NETWORK_STATE`: Required to inspect streams, fetch EJS/package releases, and transfer media.
- `android.permission.FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_DATA_SYNC`: Required to run downloads persistently without being killed by Android power management.
- `android.permission.POST_NOTIFICATIONS`: Requested at first launch / Android 13+ to display live download progress and completion notifications.
- `android.permission.WAKE_LOCK` & `RECEIVE_BOOT_COMPLETED`: Prevents CPU sleep during active transfers and supports background task recovery.
- `android.permission.READ_MEDIA_VIDEO` & `READ_MEDIA_AUDIO` (Android 13+), `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`), and `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="29"`): Scoped runtime permissions requested cleanly during first-launch onboarding so users can save to public `Downloads` on all supported Android API levels (24–35).
- **Storage Access Framework (`ACTION_OPEN_DOCUMENT_TREE`)**: Optional user-selected folder access uses scoped persistable URI grants instead of broad disk permissions.
- **NO `MANAGE_EXTERNAL_STORAGE`**: Meteora never requests "All files access".
