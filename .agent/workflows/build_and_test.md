# Antigravity Workflows

## Workflow 1: Validation & Testing
Run sequentially:
1. `flutter analyze`
2. `flutter test`
3. Package tests:
   ```bash
   (cd packages/media_engine && flutter test)
   (cd packages/package_manager && flutter test)
   (cd packages/media_library && flutter test)
   ```

## Workflow 2: Building Release Bundles
1. Validate Android SDK path:
   ```bash
   export ANDROID_HOME=/home/ameya/Android/Sdk
   ```
2. Build split ABI release APKs:
   ```bash
   flutter build apk --release --split-per-abi
   ```
