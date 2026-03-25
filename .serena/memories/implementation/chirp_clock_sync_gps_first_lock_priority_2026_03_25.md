Implemented GPS-first CHIRP clock sync integration for race sessions.

Key changes:
- Added chirp sync message models in Dart: chirp_sync_start, chirp_sync_result, chirp_sync_clear (serialize/parse support).
- Extended Nearby bridge with chirp platform APIs: getChirpCapabilities, startChirpSync, stopChirpSync, clearChirpSync.
- Extended RaceSessionController with CHIRP lock state and arbitration priority GPS > CHIRP > NTP for host-client elapsed mapping.
- monitoringSyncModeLabel now returns GPS/CHIRP/NTP/-.
- Added setup/lobby chirp controls and status UX in RaceSessionScreen.
- Added chirp payload/event handling and safety clears on disconnect/session reset paths.
- Added Android RECORD_AUDIO permission.
- Added MainActivity method channel routing for chirp methods and native event forwarding.
- Added native Kotlin acoustic engine scaffold (AudioTrack/AudioRecord timestamping, profile selection, stability stats/helpers).
- Added Kotlin unit tests for chirp math/profile/stability helper logic.

Test updates:
- Added Dart model tests for chirp messages.
- Added controller tests for chirp priority/fallback/mapping behavior.
- Updated screen test expectations for lobby post-race analysis visibility robustness.

Verification performed:
- dart format on edited Dart files.
- dart analyze on touched Dart files: clean.
- flutter tests for targeted files (race_session_models/controller/screen + nearby_bridge): passing.
- gradle :app:testDebugUnitTest (chirp engine test) and :app:compileDebugKotlin: successful.