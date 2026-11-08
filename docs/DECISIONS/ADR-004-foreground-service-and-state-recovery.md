# ADR-004: Android Foreground Service and Persistent Task Recovery

## Status
Accepted

## Context
Android aggressively terminates background processes to conserve battery and memory. Media downloads can range from a few megabytes to dozens of gigabytes and must continue reliably when the user leaves the application or locks the screen. Additionally, downloads must recover if the operating system terminates the process or the device restarts.

## Decision
1. All network transfers and external process executions are anchored inside an Android `ForegroundService` with `foregroundServiceType="dataSync"`.
2. The service displays an ongoing notification showing live speed, remaining time, progress bar, and user controls (`Pause`, `Cancel`).
3. Active tasks are continuously persisted in a local SQLite database with their current progress and resumption tokens.
4. Downloads utilize `yt-dlp`'s native `--continue` (`-c`) mechanism, preserving `.part` files on disk so downloads resume exactly where they were interrupted.

## Consequences
### Positive
- Reliable background downloads across diverse Android OEMs.
- Seamless recovery from process termination or device restarts.
- Transparent progress feedback and user control via notification shade.

### Negative
- Requires runtime notification permissions (`POST_NOTIFICATIONS` on Android 13+) and careful management of WakeLocks to prevent excessive battery drain.
