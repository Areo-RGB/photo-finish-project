# Remove dotenv and verify New Relic cleanup

Date: 2026-03-25

Changes:
- Removed `flutter_dotenv` dependency from `pubspec.yaml`.
- Removed `.env` from Flutter `assets` in `pubspec.yaml`.
- Removed dotenv import and `dotenv.load(...)` call from `lib/main.dart`.
- Ran `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`.

Verification notes:
- No tracked-source references for `newrelic|new_relic|NewRelic|newRelic`.
- No tracked-source references for `flutter_dotenv|dotenv|.env`.
- Existing `newrelic` mentions are only in generated build report artifacts.
