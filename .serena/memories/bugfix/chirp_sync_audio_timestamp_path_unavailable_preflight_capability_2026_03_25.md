Adjusted chirp sync unsupported-device behavior after runtime failure status 'Audio timestamp path unavailable'.

Changes:
- AcousticChirpSyncEngine.getCapabilities() now runs probeAudioTimestampPath(selectedProfile) and sets supported accordingly (was hardcoded true).
- AcousticChirpSyncEngine.startCalibration() now reuses probed support when selected profile matches capabilities profile; otherwise probes requested/selected profile directly before calibration.
- RaceSessionController.startChirpSyncCalibration() now short-circuits with status 'Unavailable (audio timestamp unsupported)' when capabilities.supported != true, instead of attempting start and surfacing opaque runtime failure.
- RaceSessionController now maps low-level reason 'Audio timestamp path unavailable' to user-facing text 'Audio timestamp unsupported on one or both devices' for both chirp_sync_error event handling and chirp result rejection path.

Verification:
- dart analyze for changed files: clean.
- flutter test for race_session_controller_test.dart + race_session_screen_test.dart: exit code 0.
- Android gradle chirp unit test + compileDebugKotlin: BUILD SUCCESSFUL.