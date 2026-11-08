# Building & Environment Setup

This document outlines how to configure the development environment, compile native components, run tests, and generate APK artifacts for Meteora.

---

## 1. Prerequisites

- **Host OS**: Linux, macOS, or Windows (WSL2 recommended).
- **Flutter**: 3.41.9+ (Dart 3.11.5+).
- **JDK**: OpenJDK 21+.
- **Android SDK**: Build Tools 35.0.0+, Android NDK 26+.
- **Python**: Python 3.10+ (for local test running).

### Environment Variables
Ensure the following variables are configured in your shell (`~/.bashrc` or `~/.zshrc`):
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
export PATH=$PATH:$HOME/develop/flutter/bin
```

Verify setup:
```bash
flutter doctor -v
```

---

## 2. Dependency Installation

1. Fetch root dependencies:
   ```bash
   flutter pub get
   ```

2. Fetch submodule/package dependencies:
   ```bash
   (cd packages/media_engine && flutter pub get)
   (cd packages/package_manager && flutter pub get)
   (cd packages/media_library && flutter pub get)
   ```

---

## 3. Running Unit and Integration Tests

Run the full automated test suite:
```bash
flutter test
(cd packages/media_engine && flutter test)
(cd packages/package_manager && flutter test)
(cd packages/media_library && flutter test)
```

Run static analysis:
```bash
flutter analyze
```

---

## 4. Building APKs

### Debug Build
```bash
flutter build apk --debug
```

### Production Release (ARM64 Optimized)
To produce the lightest download size for modern 64-bit Android devices:
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## 5. Android NDK Compilation (Optional Custom Binaries)

For QuickJS-NG cross-compilation targeting Android ARM64:
```bash
$ANDROID_HOME/ndk/<version>/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android33-clang \
  -O3 -s -flto -fPIE -pie qjs.c quickjs.c libregexp.c libunicode.c cutils.c -lm -o qjs
```
The resulting binary is ~1.2 MB and links directly with Android Bionic libc.
