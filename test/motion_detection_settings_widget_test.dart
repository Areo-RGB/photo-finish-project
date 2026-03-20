import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprint_sync/core/repositories/local_repository.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_controller.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_screen.dart';

void main() {
  testWidgets('threshold slider updates motion config', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = MotionDetectionController(repository: LocalRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotionDetectionScreen(
            controller: controller,
            showPreview: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = controller.config.threshold;
    await tester.drag(
      find.byKey(const ValueKey<String>('threshold_slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(controller.config.threshold, isNot(before));
  });
}
