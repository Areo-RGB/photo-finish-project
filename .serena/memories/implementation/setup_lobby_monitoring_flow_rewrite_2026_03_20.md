Implemented setup-first session flow rewrite for Sprint Sync.

What changed:
- Added new feature-first module with exactly 3 files under lib/features/race_session:
  - race_session_models.dart
  - race_session_controller.dart
  - race_session_screen.dart
- App entry in lib/main.dart now launches RaceSessionScreen directly (removed tabbed Motion/RaceSync home path).
- New flow implemented: Setup:Connection -> Lobby -> Monitoring.
- Setup supports permission request, Create Lobby (host), Join Lobby (client), endpoint discovery/connect, and Next gating at >=2 devices.
- Lobby supports host-managed per-device role assignment via popup menu (unassigned/start/split/stop), host-only Start/Split/Stop actions, and Start Monitoring.
- Role rules enforced:
  - exactly 1 start and 1 stop required for monitoring
  - split hidden/disallowed when only 2 devices
  - multiple split roles allowed when >=3 devices
  - roles lock during monitoring.
- Monitoring stage uses existing MotionDetectionScreen and host stop returns stage to lobby.

Motion pipeline changes:
- MotionDetectionEngine now emits reusable pulse triggers (MotionTriggerType.split) for each qualifying event instead of hardcoded start/stop lifecycle.
- MotionDetectionController ingestTrigger now:
  - starts run on start event
  - appends marks on split events while active
  - stops run on stop event (appends finish mark)
  - supports starting a fresh run after stop.
- MotionDetectionScreen removed RaceSyncController dependency and keeps same UI surface with static status border color.

Testing updates:
- Added test/race_session_controller_test.dart for setup gating, host/client mode, role assignment constraints, split rules, host-only actions, role lock, and stop-monitoring return behavior.
- Added test/race_session_screen_test.dart for setup UI flow (Next disabled initially, transitions after second device).
- Updated motion detection tests for pulse behavior and new controller semantics.
- Updated motion detection widget test to match screen API and preview styling changes.

Validation status:
- flutter analyze: clean
- flutter test --concurrency=1: all tests passed (40 total).

Supersession note:
- Monitoring internals from this rewrite were later superseded by Android native sensor/nanos timing path; see `implementation/native_sensor_frame_timestamps_nanos_2026_03_20` for current source-of-truth behavior and wire fields.