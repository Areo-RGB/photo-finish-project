Implemented Phase-1 high-speed attempt with fallback and live FPS overlay.

Native CameraX changes:
- Added NativeCameraFpsMode enum (hs120/normal).
- SensorNativeCameraSession now accepts preferredFpsMode and applies explicit FPS policy:
  - try fixed 120-120 first in HS mode,
  - fallback to highest normal-mode range (<=60 upper) when HS unavailable,
  - if HS apply fails, auto-fallback to normal and emit one diagnostic event.
- Session tracks active FPS mode and target upper FPS and exposes getters.
- AE/AWB lock flow remains after final selected range is applied.

Runtime FPS + downgrade:
- Added SensorNativeFpsMonitor (EMA-based observed FPS from sensor timestamp deltas).
- Warmup/threshold policy: 1.5s warmup, then if EMA < 90fps for 2.0s in HS mode, request one-time downgrade.
- SensorNativeController now:
  - starts with requested hs120,
  - emits native_frame_stats fields observedFps, cameraFpsMode, targetFpsUpper,
  - downgrades once to normal via rebind when low-FPS condition persists,
  - emits native_diagnostic events for fallback reasons.

Dart/controller/UI:
- MotionDetectionController parses/stores observedFps, cameraFpsMode, targetFpsUpper as optional state.
- Added subtle top-right preview overlay chip in motion_detection_screen.dart.
  - Text uses '--.- fps · INIT' until FPS available,
  - then '<fps> fps · HS|NORMAL'.

Tests added/updated:
- Kotlin SensorNativeMathTest:
  - HS120 selection policy and normal fallback behavior,
  - SensorNativeFpsMonitor downgrade trigger in HS mode,
  - no downgrade in NORMAL mode.
- Dart tests:
  - motion_detection_controller_test parses new native_frame_stats fields.
  - motion_detection_settings_widget_test validates overlay presence/init text and HS text update.

Validation run:
- :app:testDebugUnitTest --tests com.paul.sprintsync.sensor_native.SensorNativeMathTest passed.
- flutter test for motion_detection_controller_test.dart and motion_detection_settings_widget_test.dart passed.

Notes:
- This is Phase 1 on CameraX. Phase 2 (constrained high-speed Camera2 session) should be considered only if device validation shows HS attempts still persistently <90fps median despite successful HS configuration.