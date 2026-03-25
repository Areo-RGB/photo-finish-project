Implemented host-only unassigned clock-sync behavior and restored strict invalid-lock handling for split role.

Code changes:
- lib/features/race_session/race_session_controller.dart
  - Removed client split fallback when `mappedHostSensorNanos` is null in `onLocalMotionPulse`; split now follows same strict rejection as start/stop when lock invalid.
  - Removed host-side split fallback (`_estimateLocalSensorNanosNow`) for incoming trigger requests with missing `mappedHostSensorNanos`; host now rejects all roles consistently.
  - Added `_requiresSensorDomainClockForHostSync()` and used it in host handling of `SessionClockSyncRequestMessage` so unassigned hosts can respond using elapsed domain while monitoring.
  - Added `_effectiveHostSensorMinusElapsedNanosForSnapshot()` and used it in `_broadcastSnapshot()`; returns synthetic anchor `0` when local host role is unassigned and native sensor offset is unavailable.

Test changes:
- test/race_session_controller_test.dart
  - Added host test: unassigned host publishes synthetic anchor `hostSensorMinusElapsedNanos: 0` and answers clock sync request.
  - Renamed/updated host split test to assert rejection when mapped host sensor is missing.
  - Added client test that maps triggers after sync with synthetic host anchor (`0`).
  - Updated split invalid-lock client test to strict rejection (no payload, warning/error asserted).

Verification run:
- flutter test test/race_session_controller_test.dart (pass)
- flutter test test/race_session_screen_test.dart (pass)
