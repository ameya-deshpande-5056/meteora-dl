# Security Architecture & Policies

## 1. Threat Model & Safeguards

| Threat Vector | Potential Impact | Meteora Mitigation Strategy |
| :--- | :--- | :--- |
| **Command Injection via Malicious URL** | Remote Code Execution (RCE) via shell metacharacters (`;&\|` in query params or title). | **Zero Shell Invocation**: `ProcessBuilder` with typed argument lists. URLs are passed directly as distinct array elements after standard scheme and host verification. |
| **Tampered Component Updates** | Supply chain compromise / unauthorized binary replacement. | **Cryptographic Checksumming**: SHA-256 validation against official GitHub releases. Packages are downloaded exclusively over HTTPS directly from authorized GitHub repositories. |
| **Arbitrary Code Execution in JavaScript Engine** | Rogue scripts compromising host files or network. | **Sandboxing**: Deno runs without `--allow-all`, with network disabled by default. QuickJS-NG runs within memory-restricted boundaries without OS shell primitives. |
| **Path Traversal in Media Titles** | Writing outside app directories (`../../../../`). | Filenames generated from video titles are sanitized by stripping path separators (`/`, `\`, `:`). All output paths are validated against canonical storage roots. |
| **Background Battery / Resource Exhaustion** | System throttling, memory kills, device overheat. | Long-running downloads require explicit Foreground Service. WakeLocks are acquired with timeouts and released immediately on completion/pause. |

---

## 2. Permissions Model

Meteora adheres to the principle of least privilege:
- `android.permission.INTERNET`: Required to communicate with media servers and GitHub.
- `android.permission.FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_DATA_SYNC`: Required to run downloads persistently without being killed by Android power management.
- `android.permission.POST_NOTIFICATIONS`: Required on Android 13+ to display download progress and user control actions (pause/cancel).
- `android.permission.WAKE_LOCK`: Prevents CPU sleep while active streams are transferring.
- **NO** legacy `WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE`: We rely entirely on the modern Android MediaStore API and Scoped Storage.
