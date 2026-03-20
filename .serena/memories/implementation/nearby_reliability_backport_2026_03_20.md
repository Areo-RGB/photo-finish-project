Implemented Nearby reliability core backport from flutter/sprint into photo-finish (Sprint Sync), keeping auto-accept policy.

Changes made:
- Android Nearby bridge hardened in MainActivity.kt:
  - Added explicit role tracking (NONE/HOST/CLIENT), pendingEndpointId, requestedEndpointId, connectedEndpointIds usage refinement.
  - Normalized start flows: startHosting/startDiscovery now stop discovery+advertising+all endpoints, clear transient state, then start mode.
  - Tightened requestConnection guards for client mode and competing in-flight/pending/connected states.
  - Kept auto-accept in onConnectionInitiated while adding competing-state rejection and consistent cleanup on accept/connection failures.
  - stopHosting/stopDiscovery/stopAll/disconnect now clear tracked state in addition to stopping Nearby APIs.
  - Event contract unchanged, with consistent connection_result status fields on failures.
- Permission parity updates:
  - AndroidManifest: added ACCESS_COARSE_LOCATION (legacy), retained ACCESS_FINE_LOCATION (legacy), set NEARBY_WIFI_DEVICES usesPermissionFlags=neverForLocation.
  - Runtime required permissions: pre-S requests coarse+fine location; S+ requests BT advertise/connect/scan; T+ adds nearby wifi devices; removed CAMERA from Nearby permission gate.
- Flutter Nearby typed helper:
  - Added NearbyConnectionResultEvent parser in lib/core/services/nearby_bridge.dart for safer connection_result parsing and statusCode/statusMessage extraction.
- Race sync controller reliability updates:
  - Added deterministic role-switch reset helper to clear stale discovered/connected/error state before host/client mode switches.
  - Improved connection_result handling via typed parser; coherent endpoint set cleanup for failures and endpoint_lost.
  - Added lastConnectionStatus diagnostic getter and richer logs with status details.
  - Implemented host late-join catch-up: on new host-side connection success, send race_started then replay all prior race_split events in order.
  - Wire payload schema unchanged (race_started/race_split JSON).

Tests added:
- test/race_sync_controller_test.dart covering:
  - host catch-up replay ordering
  - role switch reset behavior
  - failed connection + endpoint_lost coherence
  - malformed connection_result guard

Verification results:
- flutter analyze: no issues
- flutter test: all tests passed
- flutter build apk --debug: succeeded, app-debug.apk built