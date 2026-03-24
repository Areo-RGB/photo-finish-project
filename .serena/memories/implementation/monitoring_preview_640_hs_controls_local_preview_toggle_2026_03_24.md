Implemented small-preview + HS controls + local preview toggle across native, controller, models, UI, and tests.

Key implementation:
- Native CameraX request size set to 640x480 for both Preview and ImageAnalysis in SensorNativeCameraSession.kt via setTargetResolution(Size(640,480)).
- NativeMonitoringConfig extended with highSpeedEnabled (default false) and parsing in SensorNativeModels.kt.
- SensorNativeController now derives requestedCameraFpsMode from config.highSpeedEnabled (hs120 only when enabled), resets to NORMAL on stop, and rebinds on facing/HS changes.
- MotionDetectionConfig extended with highSpeedEnabled field (default false), JSON round-trip, and controller method updateHighSpeedEnabled() that persists + pushes to native while streaming.
- SessionDevice extended with highSpeedEnabled (default false) with snapshot serialization/deserialization compatibility.
- RaceSessionController added assignHighSpeedEnabled(deviceId, bool), broadcasts snapshot, and local sync now applies both cameraFacing and highSpeedEnabled before monitoring and on client snapshot updates.
- RaceSessionScreen converted to StatefulWidget with local preview switch (monitoring_preview_toggle) controlling MotionDetectionScreen(showPreview: ...). Added HS control in device rows:
  - host + not monitoring: editable FilterChip (high_speed_toggle_<id>)
  - client or monitoring: read-only Chip (high_speed_state_<id>)

Tests added/updated:
- race_session_models_test.dart:
  - SessionDevice highSpeedEnabled round-trip
  - missing highSpeedEnabled defaults false
- motion_detection_controller_test.dart:
  - updateHighSpeedEnabled persists and pushes native config while streaming
- race_session_controller_test.dart:
  - host high-speed assignment updates local device and snapshot payload
  - client snapshot applies high-speed setting before monitoring starts
- race_session_screen_test.dart:
  - host can toggle HS chip in lobby
  - client sees read-only HS badge in lobby
  - monitoring preview switch hides/shows preview locally

Verification run:
- flutter test test/race_session_models_test.dart test/motion_detection_controller_test.dart test/race_session_screen_test.dart test/race_session_controller_test.dart -> All tests passed.
- android gradle unit test compile+run:
  ./gradlew.bat :app:testDebugUnitTest --tests com.paul.sprintsync.sensor_native.SensorNativeMathTest -> BUILD SUCCESSFUL.

Notes:
- High-speed default is OFF end-to-end.
- Preview visibility toggle is local UI only (not synchronized).