Implemented host stop-hosting flow and client fallback to landing (setup) on host disconnect.

Changes made:
- lib/features/race_session/race_session_controller.dart
  - Added `stopHostingAndReturnToSetup()`:
    - Host-only.
    - Sets busy state, clears transient error.
    - If monitoring is active, calls existing `stopMonitoring()` first.
    - Calls Nearby `stopAll()`.
    - Resets session to setup with `SessionNetworkRole.none` via `_resetSession(...)`.
    - Emits tracking hooks for success/failure and notifies listeners.
  - Updated `_onNearbyEvent` endpoint lost/disconnected path:
    - After removing disconnected endpoint from discovered/connected/devices, when in client mode and no connected peers remain, now calls async fallback `_handleClientDisconnectedFromHost()`.
  - Added `_handleClientDisconnectedFromHost()`:
    - Best-effort `stopAll()`.
    - Stops local monitoring capture if running.
    - Resets session to setup with network role none.
    - Notifies listeners.

- lib/features/race_session/race_session_screen.dart
  - In Lobby -> Session Actions, added host-only button:
    - key: `stop_hosting_button`
    - label: `Stop Hosting`
    - action: `controller.stopHostingAndReturnToSetup`
    - disabled while controller busy.

Tests added/updated:
- test/race_session_controller_test.dart
  - Added test: `host stopHostingAndReturnToSetup resets to landing and clears session state`.
  - Added test: `client returns to setup when host disconnects from lobby`.
  - Added test: `client returns to setup when host is lost during monitoring`.
  - Fake Nearby bridge now tracks `stopAllCalls` for assertions.

- test/race_session_screen_test.dart
  - Added test: `lobby shows stop hosting button for host and returns to setup`.
  - Added test: `client returns to setup screen when host disconnects`.

Verification:
- Ran `dart format` on edited files.
- Ran `flutter test test/race_session_controller_test.dart test/race_session_screen_test.dart`.
- Result: all tests passed.