# Claude Code Guidelines

All engineering practices, architecture principles, directory layout, coding conventions, testing rules, and security guidelines are canonically defined in:

👉 **[AGENTS.md](file:///home/ameya/meteora-dl/AGENTS.md)**

### Quick Reference Commands:
- Analysis: `flutter analyze`
- Tests: `flutter test`
- Package tests:
  - `(cd packages/media_engine && flutter test)`
  - `(cd packages/package_manager && flutter test)`
  - `(cd packages/media_library && flutter test)`
- Build debug APK: `flutter build apk --debug`
- Build ARM64 release APK: `flutter build apk --release --target-platform android-arm64 --split-per-abi`

Always consult [AGENTS.md](file:///home/ameya/meteora-dl/AGENTS.md) before making structural changes or adding dependencies.
