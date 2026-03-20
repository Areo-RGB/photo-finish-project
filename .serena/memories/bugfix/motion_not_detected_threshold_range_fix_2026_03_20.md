Fixed motion detection sensitivity bug where UI/controller still clamped threshold to 0.02..0.30, making real-world triggers unlikely.

Changes:
- motion_detection_models.dart:
  - default threshold lowered from 0.04 to 0.006
  - persisted threshold clamp changed from 0.02..0.30 to 0.001..0.08
- motion_detection_controller.dart:
  - updateThreshold clamp changed from 0.02..0.30 to 0.001..0.08
- motion_detection_screen.dart:
  - threshold slider range changed from 0.02..0.30 to 0.001..0.08

Validation:
- flutter analyze: clean
- flutter test for motion suites passed:
  - test/motion_detection_engine_test.dart
  - test/motion_detection_settings_widget_test.dart