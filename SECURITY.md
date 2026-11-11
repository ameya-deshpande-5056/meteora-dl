# Security Policy

## Supported Versions

Only the latest release and the current active development branch receive security patches.

| Version | Supported          |
| ------- | ------------------ |
| 0.0.2+  | :white_check_mark: |
| < 0.0.2 | :x:                |

---

## Reporting a Vulnerability

If you discover a security vulnerability in Meteora, please report it privately. **Do NOT open a public GitHub issue.**

Please send your disclosure report with reproduction steps to `security@meteora-app.dev` (or via private GitHub Security Advisory).

Include in your report:
1. Subsystem or component affected (`android`, `media_engine`, `package_manager`, etc.).
2. Clear proof of concept or reproduction steps.
3. Impact assessment and potential attack vectors.

We appreciate responsible disclosure and aim to acknowledge reports within 48 hours and release fixes promptly.

---

## Core Security Rules

- **Zero Command Injection**: All external binaries (`yt-dlp`, `deno`, `quickjs-ng`, `ffmpeg`) must be executed via direct array arguments (`ProcessBuilder`), never through shell string interpolation.
- **Sandboxed JavaScript Execution**: External JavaScript runtimes must run with strict sandboxing and cannot have unrestricted host filesystem or arbitrary network permissions.
- **Cryptographic Validation**: In-app binary updates must verify SHA-256 signatures before staging or replacing active binaries.
- **Anti-Bot and Access Controls**: This application does not bypass CAPTCHAs, bot protection, paywalls, or authentication gates.
