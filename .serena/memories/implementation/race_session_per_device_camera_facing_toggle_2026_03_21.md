Implemented per-device camera facing (rear/front) control in race session lobby and wired it through Dart + native monitoring pipeline.

Key changes:
- Added `SessionCameraFacing` and `SessionDevice.cameraFacing` with backward-compatible JSON fallback (`rear`) in `lib/features/race_session/race_session_models.dart`.
- Added `MotionCameraFacing` and `MotionDetectionConfig.cameraFacing` with JSON round-trip + fallback parsing in `lib/features/motion_detection/motion_detection_models.dart`.
- Added `MotionDetectionController.updateCameraFacing(...)` to persist config and push native updates while streaming.
- Added `RaceSessionController.assignCameraFacing(...)`, host-only/not-monitoring guardrails, host snapshot broadcast, and local-config sync helper.
- `RaceSessionController.startMonitoring()` now syncs local camera facing before starting detection.
- Client snapshot ingest now syncs local camera-facing config before start/while monitoring (`_onPayload`).
- Lobby UI `_buildRoleRow` now renders a per-device segmented toggle (`Rear`/`Front`) next to role control with stable keys:
  - `camera_facing_toggle_<deviceId>`
  - `camera_facing_rear_<deviceId>`
  - `camera_facing_front_<deviceId>`

Native updates:
- Added `NativeCameraFacing` and `NativeMonitoringConfig.cameraFacing` parsing from `cameraFacing` wire field in `SensorNativeModels.kt`.
- Threaded preferred facing through native bind paths:
  - `SensorNativeController.startNativeMonitoring` and preview rebind path pass `preferredFacing` to camera session.
  - `updateNativeConfig` detects camera-facing changes and rebinds while monitoring.
- `SensorNativeCameraSession` now selects camera by preferred facing with automatic fallback; emits non-fatal error when fallback is used.
- Added pure policy helper `selectCameraFacing(...)` in `SensorNativeCameraPolicy`.

Tests added/updated:
- `test/race_session_screen_test.dart`: lobby renders camera toggle and host can switch local device to front.
- `test/race_session_models_test.dart`: camera-facing JSON round-trip and missing-field fallback to rear.
- `test/race_session_controller_test.dart`: host assignment updates snapshot payload; client snapshot applies front-facing before monitoring start.
- `test/motion_detection_controller_test.dart`: `updateCameraFacing` persists and pushes native update while streaming.
- `android/app/src/test/kotlin/.../SensorNativeMathTest.kt`: preferred-facing selection + fallback policy tests.

Verification run:
- `flutter test test/race_session_screen_test.dart test/race_session_models_test.dart test/race_session_controller_test.dart test/motion_detection_controller_test.dart` ✅
- `android\\gradlew.bat :app:testDebugUnitTest` ✅
- Full `flutter test` still reports unrelated pre-existing failures in `race_sync_*` tests (missing removed race_sync feature files) and pre-existing `local_repository_test` threshold expectation mismatch (expects 0.04, actual defaults 0.006).