Implemented Sprint Sync v1 app scaffold and core features in Flutter with Android-only Nearby bridge and recreated camera motion detection.

Key implementation:
- Rebrand/app ID: Android namespace/applicationId set to com.paul.sprintsync; app label Sprint Sync.
- New Flutter app structure with feature-first folders:
  - motion_detection: screen/controller/models
  - race_sync: screen/controller/models
  - core: app models, local repository, nearby bridge
- Motion detection recreation:
  - camera stream uses back camera, ResolutionPreset.medium, enableAudio=false, ImageFormatGroup.yuv420
  - processing every N frames (default 2), Y plane only, vertical ROI
  - normalized delta scoring mean(abs(curr-prev))/255
  - EMA baseline and effectiveScore=max(0, raw-baseline)
  - trigger rules implemented: 3 consecutive over threshold, re-arm below threshold*0.6 for 200ms, cooldown default 900ms
  - race semantics implemented: first trigger=start, subsequent triggers=splits
- Nearby integration:
  - Flutter channels: com.paul.sprintsync/nearby_methods and /nearby_events
  - Android MainActivity implemented with Google Nearby Connections bridge
  - methods: requestPermissions, startHosting, stopHosting, startDiscovery, stopDiscovery, requestConnection, sendBytes, disconnect, stopAll
  - events emitted: endpoint_found, endpoint_lost, connection_result, endpoint_disconnected, payload_received, permission_status, error
  - auto-accept connection on initiation (open local session behavior)
- Race sync:
  - host authority logic for start/split broadcast
  - payload wire messages: race_started, race_split JSON
  - local session state and last run persistence
- Persistence:
  - SharedPreferences persistence for MotionDetectionConfig and LastRunResult

Files of note:
- android/app/src/main/kotlin/com/paul/sprintsync/MainActivity.kt
- lib/core/services/nearby_bridge.dart
- lib/features/motion_detection/{motion_detection_models.dart,motion_detection_controller.dart,motion_detection_screen.dart}
- lib/features/race_sync/{race_sync_models.dart,race_sync_controller.dart,race_sync_screen.dart}
- lib/core/repositories/local_repository.dart
- lib/main.dart

Verification run results:
- flutter pub get: success
- flutter test: all tests passed (6 total)
- flutter analyze: no issues found
- flutter build apk --debug: success, built build/app/outputs/flutter-apk/app-debug.apk

Notes:
- Added dependency camera 0.12.0+1 and shared_preferences.
- Added play-services-nearby 19.3.0 in Android app dependencies.