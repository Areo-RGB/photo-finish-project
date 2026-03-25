Implemented clock sync latency optimizations in host native path and client burst sending.

Code changes:
- android/app/src/main/kotlin/com/paul/sprintsync/MainActivity.kt
  - Added method-channel command `configureNativeClockSyncHost` with booleans: `enabled`, `requireSensorDomainClock`.
  - Added host-side interception in `payloadCallback.onPayloadReceived` via `tryRespondToClockSyncRequest(...)`.
  - For recognized `clock_sync_request`, host now responds natively with wire-compatible JSON (`clock_sync_response`) and does not forward that request event to Dart.
  - Added strict gating: native response uses `sensorNativeController.currentClockSyncElapsedNanos(...)`; when `requireSensorDomainClock` is true and no valid sensor-derived sample exists, request is swallowed with no response (matching prior Dart behavior for strict mode).
  - Reset native clock-sync host config in `clearTransientState()`.

- android/app/src/main/kotlin/com/paul/sprintsync/sensor_native/SensorNativeController.kt
  - Added cached sensor-derived elapsed sample fields:
    - `lastSensorElapsedSampleNanos`
    - `lastSensorElapsedSampleCapturedAtNanos`
  - Added `currentClockSyncElapsedNanos(maxSensorSampleAgeNanos, requireSensorDomain)` helper:
    - Projects cached sensor-derived elapsed when fresh.
    - Returns null if strict sensor-domain is required and sample unavailable.
    - Falls back to `SystemClock.elapsedRealtimeNanos()` otherwise.
  - Updated `updateStreamTelemetry(...)` to cache sample/projection anchors.
  - Cleared cached sample fields in `resetStreamState()`.

- lib/core/services/nearby_bridge.dart
  - Added `configureNativeClockSyncHost(...)` method-channel wrapper.

- lib/features/race_session/race_session_controller.dart
  - Added `_syncNativeClockSyncHostConfig()` to push host/native clock policy to Kotlin.
  - Called sync on controller init, role assignment changes, monitoring start/stop, and session reset.
  - Updated `_runClockSyncBurst(...)` to queue all `sendBytes` requests and await once with `Future.wait`.
  - Added failed-send cleanup path: on send failure, remove request nanos from `_pendingClockSyncRequestSendNanos`.

Tests:
- test/race_session_controller_test.dart
  - Added test: `client enqueues full clock sync burst before send futures resolve`.
  - Added test: `failed clock sync sends are removed from pending set for future bursts`.
  - Extended fake bridge with hold/fail send controls and override for `configureNativeClockSyncHost(...)`.
- test/race_session_screen_test.dart
  - Added fake bridge override for `configureNativeClockSyncHost(...)`.

Verification:
- `dart format` on modified Dart files.
- `flutter test test/race_session_controller_test.dart test/race_session_screen_test.dart` -> All tests passed.
- `dart analyze` on modified Dart/test files -> No issues found.
- `./gradlew.bat :app:compileDebugKotlin` (android/) -> BUILD SUCCESSFUL.
