import 'package:sprint_sync/features/motion_detection/motion_detection_controller.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_models.dart';
import 'package:sprint_sync/features/race_session/race_session_models.dart';

void ingestStandalonePulse(
  MotionDetectionController controller,
  MotionTriggerEvent trigger,
) {
  final type = controller.isRunActive
      ? MotionTriggerType.split
      : MotionTriggerType.start;
  controller.ingestTrigger(
    MotionTriggerEvent(
      triggerMicros: trigger.triggerMicros,
      score: trigger.score,
      type: type,
      splitIndex: controller.currentSplitMicros.length + 1,
    ),
    forwardToSync: false,
  );
}

void syncMotionControllerFromTimeline(
  MotionDetectionController controller,
  SessionRaceTimeline timeline,
) {
  controller.resetRace();
  final startedAtEpochMs = timeline.startedAtEpochMs;
  if (startedAtEpochMs == null) return;

  final startedAtMicros = startedAtEpochMs * 1000;
  controller.ingestTrigger(
    MotionTriggerEvent(
      triggerMicros: startedAtMicros,
      score: 0,
      type: MotionTriggerType.start,
      splitIndex: 0,
    ),
    forwardToSync: false,
  );

  for (int i = 0; i < timeline.splitMicros.length; i += 1) {
    controller.ingestTrigger(
      MotionTriggerEvent(
        triggerMicros: startedAtMicros + timeline.splitMicros[i],
        score: 0,
        type: MotionTriggerType.split,
        splitIndex: i + 1,
      ),
      forwardToSync: false,
    );
  }

  final stopElapsed = timeline.stopElapsedMicros;
  if (stopElapsed == null) return;
  controller.ingestTrigger(
    MotionTriggerEvent(
      triggerMicros: startedAtMicros + stopElapsed,
      score: 0,
      type: MotionTriggerType.stop,
      splitIndex: 0,
    ),
    forwardToSync: false,
  );
}
