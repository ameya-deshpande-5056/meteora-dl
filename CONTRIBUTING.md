# Contributing to Meteora

Thank you for your interest in contributing to **Meteora**! We welcome bug reports, feature enhancements, documentation improvements, and architectural optimizations.

---

## 1. Development Setup

1. Ensure you have installed:
   - **Flutter SDK**: 3.41+ (`flutter doctor` should report no issues).
   - **Android SDK**: Build tools 35.0.0+, Android NDK.
   - **JDK**: OpenJDK 21+.
2. Clone the repository and install packages:
   ```bash
   git clone https://github.com/meteora-app/meteora-dl.git
   cd meteora-dl
   flutter pub get
   (cd packages/media_engine && flutter pub get)
   (cd packages/package_manager && flutter pub get)
   (cd packages/media_library && flutter pub get)
   ```
3. Run static analyzer and tests:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 2. Commit Message Conventions

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat(scope)`: A new feature (e.g. `feat(engine): add AV1 hardware capability check`)
- `fix(scope)`: A bug fix (e.g. `fix(service): resolve foreground notification crash on Android 14`)
- `docs(scope)`: Documentation changes (e.g. `docs(adr): add ADR-002 on JS runtimes`)
- `refactor(scope)`: Code changes that neither fix bugs nor add features
- `perf(scope)`: Performance optimization
- `test(scope)`: Adding or updating tests
- `chore(scope)`: Maintenance or build script updates

---

## 3. Pull Request Guidelines

1. **Branch Naming**: Use `feature/short-description`, `fix/short-description`, or `docs/short-description`.
2. **Quality Gates**:
   - `flutter analyze` must pass with zero errors and zero warnings.
   - All tests in `test/` and `packages/*/test/` must pass.
3. **Documentation**: Update the relevant markdown files in `docs/` and log any major design shifts in `docs/DECISIONS/`.
4. **Agent Rules**: AI coding assistants contributing code must strictly adhere to [AGENTS.md](AGENTS.md).
