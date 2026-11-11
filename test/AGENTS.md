# Test Subsystem Instructions (`test/AGENTS.md`)

## Testing Standards & Coverage Goals
All business logic, format selection rules, update workflows, and native bridge data transfers must have comprehensive unit tests.

## Structure
- `test/widget_test.dart`: Root smoke, onboarding, navigation, Settings & Theme picker tests.
- `test/playlist_ui_test.dart`: Playlist detection and batch item selection UI tests.
- `test/user_requirements_test.dart`: End-to-end UI tests for simple download/codec/subtitle selection, Download Location SAF flow, external player `playMedia` invocation, Liquid Glass surfaces, and first-launch setup persistence.
- `packages/media_engine/test/`: Format selection, `DownloadMode` / `SimpleDownloadCommandBuilder`, JSON extraction parsing, playlist parsing, stream pairing.
- `packages/package_manager/test/`: Release parsing, checksum verification, atomic swap simulations.
- `packages/media_library/test/`: SQLite database schema operations (`download_tasks`, `media_items`, `app_settings`), metadata extraction parsing.

## Execution
Run all tests via:
```bash
flutter test
(cd packages/media_engine && flutter test)
(cd packages/package_manager && flutter test)
(cd packages/media_library && flutter test)
```
Ensure 100% pass rate before committing changes.
