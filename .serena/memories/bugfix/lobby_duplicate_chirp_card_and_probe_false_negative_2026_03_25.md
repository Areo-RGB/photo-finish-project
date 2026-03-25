User-reported bug: Race Lobby showed two Audio Chirp Sync cards and chirp status repeatedly failed with 'Audio timestamp path unavailable'.

Fixes applied:
1) UI duplication fix in race_session_screen.dart:
- Removed second _buildChirpSyncCard() insertion at end of lobby list.
- Lobby now renders chirp card exactly once.

2) Chirp integration robustness fix in AcousticChirpSyncEngine.probeAudioTimestampPath:
- Added source fallback sequence: UNPROCESSED then MIC.
- Added warm-up and retry loop (up to ~350ms) before deciding timestamp path unavailable.
- Added AudioRecord timestamp check fallback from TIMEBASE_BOOTTIME to TIMEBASE_MONOTONIC.
- Kept strict success condition requiring both record and track timestamps.

Validation:
- dart format and dart analyze (screen/controller) clean.
- flutter tests (race_session_screen_test + race_session_controller_test) passed.
- Android gradle chirp unit test + compileDebugKotlin passed (BUILD SUCCESSFUL).