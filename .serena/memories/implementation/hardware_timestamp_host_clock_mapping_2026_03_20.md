Implemented cross-device trigger timestamp mapping to a host source-of-truth clock in race session flow.

Core changes:
- Extended SessionTriggerRequestMessage with optional mappedHostMicros.
- Added new wire messages:
  - SessionClockSyncRequestMessage (clock_sync_request, clientSendMicros)
  - SessionClockSyncResponseMessage (clock_sync_response, clientSendMicros, hostReceiveMicros, hostTransmitMicros)
- RaceSessionController now supports injected clock provider via nowMicros for deterministic tests.
- Added client-side host clock estimation using NTP-style midpoint approximation:
  - offset = hostReceiveMicros - (clientSendMicros + RTT/2)
  - smoothed with weighted average across samples.
- Client requests clock sync:
  - when connection_result indicates connected in client mode
  - when monitoring turns on via host snapshot
- Client sends mappedHostMicros with trigger_request when offset quality is acceptable (RTT <= 400000us).
- Host applies mappedHostMicros when present; otherwise falls back to raw triggerMicros.
- Host responds to clock_sync_request with clock_sync_response.
- Session reset and disconnect clear cached offset/RTT state.

Tests:
- Added test/race_session_models_test.dart:
  - trigger request optional mappedHostMicros serialization/parsing
  - clock sync request serialization/parsing
  - clock sync response serialization/parsing
- Updated test/race_session_controller_test.dart:
  - host applies mapped host timestamp from client trigger request
  - client sends host-mapped trigger after clock sync response
  - enhanced fake bridge to capture sendBytes payloads
  - fixture supports deterministic nowMicros injection

Verification run:
- flutter test test/race_session_models_test.dart test/race_session_controller_test.dart (passed)

Notes:
- Camera plugin (camera 0.12.0+1) does not expose per-frame hardware timestamp field in CameraImage API, so this change focuses on cross-device timestamp-domain mapping for trigger messages.