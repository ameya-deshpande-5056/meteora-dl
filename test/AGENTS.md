# Test Subsystem Instructions (`test/AGENTS.md`)

## Testing Standards & Coverage Goals
All business logic, format selection rules, update workflows, and native bridge data transfers must have comprehensive unit tests.

## Structure
- `test/widget_test.dart`: Root smoke and UI navigation tests.
- `packages/media_engine/test/`: Format selection, JSON extraction parsing, stream pairing.
- `packages/package_manager/test/`: Release parsing, checksum verification, atomic swap simulations.
- `packages/media_library/test/`: Drift database schema operations, metadata extraction parsing.

## Execution
Run all tests via:
```bash
flutter test
(cd packages/media_engine && flutter test)
(cd packages/package_manager && flutter test)
(cd packages/media_library && flutter test)
```
Ensure 100% pass rate before committing changes.
