Analyzed installed Android package com.ultrajuicy.photofinish (versionName 5.2.2, versionCode 568, updated 2026-01-25) pulled from connected device via adb.

Static decompilation setup:
- JADX 1.5.5 from C:/Users/paul/AppData/Local/Programs/jadx-1.5.5/README.md guidance.
- Decompiled base.apk to C:/Users/paul/AppData/Local/Temp/photofinish_apk_analysis/jadx_out_20260320_081944 (with expected partial decompilation errors).
- Split APK contains lib/arm64-v8a/libapp.so and libflutter.so (Flutter AOT release).

Architecture findings:
- Flutter app entry: com.photofinish.app.MainActivity.
- Native Android plugin surface mainly for latency/IO-critical features:
  - BLE hosting channel: "ble" (startHosting/stopHosting)
  - BLE joining channel: "bleJoin" + event channels "ble/joinEvents" and "ble/debugEvents"
  - Recording/start detection channel: "com.ultrajuicy.photofinishflutter/AndroidRecording"
  - Audio stream events: "com.photofinish.app/AndroidAudioStream"
  - Start-gun threshold events: "com.photofinish.app/AndroidStartGunThresholdExceededTimestamps"
  - Sound playback channel: "com.ultrajuicy.photofinishflutter/audio"
  - Mic calibration channel: "com.ultrajuicy.photofinishflutter/AndroidMicrophoneCalibrationMethods"
  - Legacy migration channels: "com.ultrajuicy.photofinish/legacy_db", "com.ultrajuicy.photofinish/legacy_shared_preferences", "com.ultrajuicy.photofinish/legacy_promo_key"

Feature/data clues from AOT string extraction and Java glue:
- Session modes and starts present: Basic, Advanced, Series, Flying Start, Ready Set Go, Three Two One Go, Sound Detection, Touch Start.
- Core entities visible in symbols/strings: AthleteDto, HistoryRunDto, HistorySessionDto, HistorySplitDto, legacy equivalents for migration.
- Firestore integration present with queue-style sync and split/run/session operations.
- CSV export path observed: /photo-finish-export.csv
- Promo/paywall flows present (promo key validation states, paywall state).
- Tutorials and localized help strings embedded (multilingual).

Manifest-level integrations and permissions:
- CAMERA, RECORD_AUDIO, INTERNET, Bluetooth/BLE permissions, notifications, billing.
- Deep links include photofinish://open and photofinish.app.link hosts.
- Integrations observed: Firebase (Auth/Firestore/Functions/Messaging/Storage/Crashlytics/Analytics), Branch, RevenueCat.

Limitations:
- Full Dart source is not directly recoverable from release AOT (libapp.so); recovered behavior is inferred from strings + native plugin layer + manifest/resources.
