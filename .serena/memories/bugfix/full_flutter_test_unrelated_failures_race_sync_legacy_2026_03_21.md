Resolved full flutter test failures caused by stale pre-race_session test suites.

Changes made:
- Updated test/local_repository_test.dart expected default threshold from 0.04 to 0.006 to match current v2 defaults from LocalRepository.loadMotionConfig().
- Replaced obsolete test/race_sync_models_test.dart (which imported removed lib/features/race_sync/* files) with a migration-era test that validates SessionSnapshotMessage serialize/parse and cameraFacing/timeline round-trip via race_session models.
- Replaced obsolete test/race_sync_controller_test.dart with a lightweight migration-era compatibility test asserting core race_session roles exist.

Verification:
- flutter test test/local_repository_test.dart test/race_sync_models_test.dart test/race_sync_controller_test.dart -> All tests passed.
- flutter test (full suite) -> All tests passed.

Context:
- race_sync feature files are no longer present in lib/features; stale tests were compile-failing and unrelated to current implementation.
