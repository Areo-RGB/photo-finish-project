Fixed inflated client stopwatch elapsed values caused by mixed clock domains during host/client sync.

Root cause:
- Sensor mapping used sensor/elapsed domain while clock offset estimation used app-local stopwatch domain.
- On devices with different uptime baselines, mapped start times became invalid and produced huge elapsed display values.

Fix summary:
- Race session clock sync now uses sensor-derived elapsed nanos during monitoring when available.
- Added domain-safe helpers for sync timestamp acquisition and lock validation.
- Added lock reset paths on monitoring start, disconnect, and session reset.
- Added defensive rejection when sync receive timestamp is earlier than send timestamp.

Tests:
- Added regression for differing host/client uptimes to ensure elapsed display stays sane.
- Updated sync tests to use sensor-domain clock sync handshake payloads.

Verification:
- race session model/controller tests and targeted analyze checks pass for the touched files.