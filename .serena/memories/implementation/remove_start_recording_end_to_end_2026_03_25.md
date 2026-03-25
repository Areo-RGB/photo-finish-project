Implemented full removal of the Start Recording feature across Flutter session flow, wire protocol, and native bridge handlers.

Changes made:
- Race session model:
  - Removed SessionStage.recording enum value.
  - Removed SessionSnapshotMessage.recordingActive field from constructor/state/json parse+encode.
  - Removed SessionRecordingAnalysisResultMessage class entirely.
- Race session UI:
  - Removed lobby Start Recording action button.
  - Removed recording stage route case from RaceSessionScreen switch.
  - Removed recording stage scaffold (_buildRecordingScaffold).
  - Lobby status now only shows refinement status text.
- Race session controller:
  - Removed recording state/fields/getters (recordingActive, recordingStatusText, awaiting/finalize/results/timer, local HS recording active).
  - Removed canStartRecording getter.
  - Removed startRecording/stopRecording methods.
  - Removed all recording-transition handling from snapshot client updates.
  - Removed recording-analysis payload handling in _onPayload.
  - Removed recording helper methods: start/stop local HS recording, recording role expectations, scan direction, local recording analysis host/client methods, status updates, finalize flow.
  - Removed recordingActive from _broadcastSnapshot payload.
  - Removed recording cleanup branches from resetRun/_resetSession/dispose.
- Motion/native Dart APIs:
  - Removed NativeSensorBridge methods: startHighSpeedRecording, stopHighSpeedRecording, analyzeHighSpeedRecording.
  - Removed MotionDetectionController wrappers for those methods.
  - Removed Dart models HsScanDirection and HsOfflineRecordingAnalysisResult (no longer used).
- Android native method-channel handling:
  - Removed SensorNativeController method dispatch entries for startHighSpeedRecording, stopHighSpeedRecording, analyzeHighSpeedRecording.
  - Removed corresponding method implementations.
  - Removed HS recording manager/artifact state tracking fields and cleanup helpers used only by that flow.
  - Removed hs_recording_state event emitter.
  - Removed resetNativeRun reference to clearRecordedArtifacts.

Test updates:
- Removed recording-specific widget test from race_session_screen_test.dart.
- Added assertion in lobby->monitoring flow that Start Recording is not present.
- Removed recording-specific controller tests (start/stop recording flow, recording analysis payload mapping, recording-only refinement impact case).
- Updated fake NativeSensorBridge test doubles to remove now-nonexistent recording API overrides and related helper structs/fields.

Verification run results:
- flutter test test/race_session_controller_test.dart test/race_session_screen_test.dart test/race_session_models_test.dart -> PASS
- android/gradlew.bat :app:compileDebugKotlin -> PASS (after removing stale clearRecordedArtifacts call)
- android/gradlew.bat :app:testDebugUnitTest --tests com.paul.sprintsync.sensor_native.SensorNativeMathTest -> PASS