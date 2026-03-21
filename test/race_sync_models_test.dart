import 'package:flutter_test/flutter_test.dart';
import 'package:sprint_sync/features/race_session/race_session_models.dart';

void main() {
  test(
    'session snapshot message serializes and parses after race_sync migration',
    () {
      const message = SessionSnapshotMessage(
        stage: SessionStage.monitoring,
        monitoringActive: true,
        devices: <SessionDevice>[
          SessionDevice(
            id: 'device-1',
            name: 'Device 1',
            role: SessionDeviceRole.start,
            cameraFacing: SessionCameraFacing.front,
            isLocal: true,
          ),
        ],
        timeline: SessionRaceTimeline(
          startedSensorNanos: 1000,
          splitElapsedNanos: <int>[200],
          stopElapsedNanos: null,
        ),
      );

      final decoded = SessionSnapshotMessage.tryParse(message.toJsonString());

      expect(decoded, isNotNull);
      expect(decoded!.devices.single.cameraFacing, SessionCameraFacing.front);
      expect(decoded.timeline.startedSensorNanos, 1000);
      expect(decoded.timeline.splitElapsedNanos, <int>[200]);
    },
  );
}
