# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Sprint Sync is a Flutter/Android mobile app for sprint race timing using camera-based motion detection and multi-device synchronization (Google Nearby Connections). No backend services or databases are required.

### Environment

- **Flutter SDK** is installed at `/opt/flutter` (stable channel). PATH and `ANDROID_HOME`/`ANDROID_SDK_ROOT` are configured in `~/.bashrc`.
- **Android SDK** is at `/opt/android-sdk` with platform-tools, build-tools, NDK, and CMake auto-installed during the first build.
- **JDK 21** (system-provided) is used; Gradle 8.14 and AGP 8.11.1 are compatible with it. The `compileOptions` target Java 17 source compatibility.

### Common commands

| Task | Command |
|---|---|
| Install Dart deps | `flutter pub get` |
| Lint / analyze | `flutter analyze` (lib-only: `flutter analyze lib/`) |
| Run unit/widget tests | `flutter test` |
| Build debug APK | `flutter build apk --debug` |
| Run on web (dev) | `flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0` |

### Known pre-existing test issues

- `test/race_sync_controller_test.dart` and `test/race_sync_models_test.dart` reference `lib/features/race_sync/race_sync_controller.dart` and `lib/features/race_sync/race_sync_models.dart` which do not exist in the repo. These tests will fail to compile.
- Several tests in `motion_detection_engine_test.dart`, `local_repository_test.dart`, `race_session_screen_test.dart`, and `motion_detection_settings_widget_test.dart` have pre-existing assertion failures unrelated to environment setup.

### Gotchas

- The first `flutter build apk --debug` auto-downloads NDK 28.2 and CMake 3.22.1 (~3 min). Subsequent builds are faster.
- Flutter web support may not be configured by default. If `flutter run -d web-server` fails with "not configured to build on the web", run `flutter create .` first (this adds web platform files).
- Camera and Nearby Connections features require physical Android devices — they cannot be tested in emulators or web.
