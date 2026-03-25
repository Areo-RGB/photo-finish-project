Implemented dual-strategy Nearby controls.

Changes:
- Added NearbyConnectionStrategy enum in lib/core/services/nearby_bridge.dart with wire values 'star' and 'point_to_point'.
- Updated NearbyBridge.startHosting/startDiscovery to accept optional strategy parameter (default STAR) and send 'strategy' over MethodChannel.
- In RaceSessionController:
  - createLobby/joinLobby now delegate to strategy-specific helpers and pass STAR explicitly.
  - Added createLobbyPointToPoint() and joinLobbyPointToPoint() that pass POINT_TO_POINT.
  - Added strategy value to _trackNearby statusMessage for started/failed host/discovery events.
- In RaceSessionScreen setup card:
  - Added host_point_to_point_button labeled 'Host 1:1' -> controller.createLobbyPointToPoint
  - Added join_point_to_point_button labeled 'Join 1:1' -> controller.joinLobbyPointToPoint
  - Preserved existing Host/Join buttons and behavior.
- In android MainActivity:
  - Replaced single fixed STRATEGY usage with NearbyTransportStrategy enum + per-call parsing from optional 'strategy' arg (fallback STAR).
  - startHosting/startDiscovery now accept parsed strategy and set AdvertisingOptions/DiscoveryOptions accordingly.
  - Added activeStrategy runtime state.
  - Added strict 1:1 rejection in onConnectionInitiated when active role=HOST and active strategy=POINT_TO_POINT with existing connected/pending peer; emits connection_result failure + error event.
- Added method-channel payload tests in test/nearby_bridge_test.dart.
- Updated race_session_controller_test and race_session_screen_test fakes to accept strategy parameter and track last strategy.
- Added tests:
  - Controller: createLobby/createLobbyPointToPoint/joinLobby/joinLobbyPointToPoint strategy assertions.
  - Screen: presence of Host 1:1 and Join 1:1 buttons; tapping both uses point-to-point strategy.

Verification:
- flutter test test/nearby_bridge_test.dart -> PASS
- flutter test test/race_session_controller_test.dart -> PASS
- flutter test test/race_session_screen_test.dart -> PASS
- cmd.exe /c gradlew.bat app:compileDebugKotlin (android/) -> BUILD SUCCESSFUL