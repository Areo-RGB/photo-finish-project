Implemented Android-native monitoring with hardware frame timestamps and nanos-only race timing protocol.

Architecture-impacting changes:
- Added native CameraX sensor module (`sensor_native`) with method/event channels and native motion math parity.
- Motion and race session pipeline migrated from micros/epoch fields to nanos fields end-to-end.
- Race session clock mapping now uses elapsed-nanos sync + sensor/elapsed offsets to map client triggers into host sensor domain.

Wire/protocol updates:
- `trigger_request`: `triggerSensorNanos`, optional `mappedHostSensorNanos`.
- `clock_sync_request`: `clientSendElapsedNanos`.
- `clock_sync_response`: `clientSendElapsedNanos`, `hostReceiveElapsedNanos`, `hostSendElapsedNanos`.
- Host snapshot includes `hostSensorMinusElapsedNanos` for client sensor-domain mapping.

Behavioral safeguards:
- Host rejects remote triggers that do not include valid mapped host sensor nanos.
- Client rejects/blocks trigger forwarding when lock is invalid (no sync, stale sync, or RTT > 400ms).

Integration/test coverage:
- Dart tests updated for nanos serialization, controller mapping, and stale/no-sync/high-RTT rejection.
- Android unit tests added for native sensor math.

Supersession:
- Supersedes older micros-era memory `implementation/hardware_timestamp_host_clock_mapping_2026_03_20`.