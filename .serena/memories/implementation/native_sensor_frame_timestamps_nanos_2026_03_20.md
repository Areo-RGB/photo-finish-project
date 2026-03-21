Implemented Android native sensor-frame timestamp pipeline and nanos-only race protocol migration.

Key changes:
- Added Kotlin native CameraX module under android/app/src/main/kotlin/com/paul/sprintsync/sensor_native/ with 3 files:
  - SensorNativeController.kt (method/event channels, CameraX ImageAnalysis analyzer, native lifecycle and events)
  - SensorNativeModels.kt (native config + event model types)
  - SensorNativeMath.kt (ROI frame differ, detector parity math, offset smoothing, sensor<->elapsed helpers)
- Registered native module from MainActivity.kt, including onPause stop hook and onDestroy cleanup.
- Added CameraX 1.5.3 + guava + concurrent-futures dependencies in android/app/build.gradle.kts.
- Added root android/build.gradle.kts subproject dependency injection for camera_android_camerax concurrent-futures compile stability.

Dart nanos migration:
- Motion/race/session models now use nanos fields end-to-end:
  - MotionTriggerEvent.triggerSensorNanos
  - MotionFrameStats.frameSensorNanos
  - SessionRaceTimeline.startedSensorNanos/splitElapsedNanos/stopElapsedNanos
- Replaced race session wire payload fields:
  - trigger_request: triggerSensorNanos + mappedHostSensorNanos
  - clock_sync_request: clientSendElapsedNanos
  - clock_sync_response: clientSendElapsedNanos/hostReceiveElapsedNanos/hostSendElapsedNanos
- Removed micros/epoch compatibility paths in race session models and parsing.

Race session mapping logic:
- RaceSessionController now syncs clocks via elapsed nanos midpoint estimation.
- Added host-minus-client elapsed offset tracking with smoothing.
- Added stale/invalid clock-lock rejection (RTT > 400ms or stale/no sync).
- Mapped client trigger sensor nanos into host sensor domain using:
  - client sensor->elapsed (local native offset)
  - host-minus-client elapsed offset
  - host elapsed->sensor (host native offset received in snapshot)
- Host snapshot now broadcasts hostSensorMinusElapsedNanos.
- Trigger requests without mappedHostSensorNanos are explicitly rejected on host.

Motion integration/UI:
- MotionDetectionController now consumes native frame stats + triggers and updates sensorMinusElapsedNanos.
- Race monitoring uses MotionDetectionScreen(showPreview: false), effectively disabling preview in monitoring mode.
- MotionDetectionScreen lifecycle now always stops detection when app is paused/inactive.
- main.dart now injects NativeSensorBridge into MotionDetectionController.

Persistence:
- LastRunResult migrated to startedSensorNanos + splitElapsedNanos.
- LocalRepository key moved to last_run_result_v2_nanos.

Tests updated/added:
- Dart:
  - test/motion_detection_controller_test.dart (nanos + fake native bridge)
  - test/race_session_controller_test.dart (nanos mapping + stale/no-sync/high-RTT rejection)
  - test/race_session_models_test.dart (nanos wire serialization)
  - test/motion_detection_engine_test.dart updated for nanos API
  - test/motion_detection_settings_widget_test.dart and test/race_session_screen_test.dart aligned to current UI/native path
- Android:
  - android/app/src/test/kotlin/com/paul/sprintsync/sensor_native/SensorNativeMathTest.kt

Verification highlights:
- Passed:
  - flutter test test/motion_detection_controller_test.dart test/race_session_controller_test.dart test/race_session_models_test.dart
  - .\gradlew.bat :app:testDebugUnitTest
  - .\gradlew.bat :app:testDebugUnitTest --tests com.paul.sprintsync.sensor_native.SensorNativeMathTest
- Full android testDebugUnitTest still fails in shared_preferences_android plugin module tests (DataStore IO exceptions), unrelated to app module changes.
- flutter analyze still reports existing unresolved race_sync_* test errors (missing race_sync package symbols), unrelated to new nanos/native module changes.