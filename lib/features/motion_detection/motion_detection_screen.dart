import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_controller.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_models.dart';

class MotionDetectionScreen extends StatefulWidget {
  const MotionDetectionScreen({
    super.key,
    required this.controller,
    this.showPreview = true,
  });

  final MotionDetectionController controller;
  final bool showPreview;

  @override
  State<MotionDetectionScreen> createState() => _MotionDetectionScreenState();
}

class _MotionDetectionScreenState extends State<MotionDetectionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showPreview) {
      widget.controller.initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.showPreview) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      widget.controller.stopDetection();
    }
    if (state == AppLifecycleState.resumed) {
      widget.controller.initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final config = widget.controller.config;
        final stats = widget.controller.latestStats;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.showPreview)
              _buildPreviewCard(widget.controller.cameraController),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection Guidance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For best reliability, align athletes with the vertical detection line and '
                      'allow a short 1.5-2m run-up before crossing.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: widget.controller.isLoading
                              ? null
                              : widget.controller.initializeCamera,
                          child: const Text('Init Camera'),
                        ),
                        FilledButton(
                          onPressed: widget.controller.isStreaming
                              ? null
                              : widget.controller.startDetection,
                          child: const Text('Start Detection'),
                        ),
                        OutlinedButton(
                          onPressed: widget.controller.isStreaming
                              ? widget.controller.stopDetection
                              : null,
                          child: const Text('Stop Detection'),
                        ),
                        OutlinedButton(
                          onPressed: widget.controller.resetRace,
                          child: const Text('Reset Race'),
                        ),
                      ],
                    ),
                    if (widget.controller.errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.controller.errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Threshold: ${config.threshold.toStringAsFixed(3)}'),
                    Slider(
                      key: const ValueKey<String>('threshold_slider'),
                      value: config.threshold,
                      min: 0.02,
                      max: 0.30,
                      onChanged: (value) =>
                          widget.controller.updateThreshold(value),
                    ),
                    Text('ROI center: ${config.roiCenterX.toStringAsFixed(2)}'),
                    Slider(
                      key: const ValueKey<String>('roi_center_slider'),
                      value: config.roiCenterX,
                      min: 0.20,
                      max: 0.80,
                      onChanged: (value) =>
                          widget.controller.updateRoiCenter(value),
                    ),
                    Text('ROI width: ${config.roiWidth.toStringAsFixed(2)}'),
                    Slider(
                      key: const ValueKey<String>('roi_width_slider'),
                      value: config.roiWidth,
                      min: 0.05,
                      max: 0.40,
                      onChanged: (value) =>
                          widget.controller.updateRoiWidth(value),
                    ),
                    Text('Cooldown: ${config.cooldownMs} ms'),
                    Slider(
                      key: const ValueKey<String>('cooldown_slider'),
                      value: config.cooldownMs.toDouble(),
                      min: 300,
                      max: 2000,
                      onChanged: (value) =>
                          widget.controller.updateCooldown(value.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Stats',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Raw score: ${stats?.rawScore.toStringAsFixed(4) ?? '-'}',
                    ),
                    Text(
                      'Baseline: ${stats?.baseline.toStringAsFixed(4) ?? '-'}',
                    ),
                    Text(
                      'Effective: ${stats?.effectiveScore.toStringAsFixed(4) ?? '-'}',
                    ),
                    Text('Timestamp: ${stats?.timestampMicros ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Triggers',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (widget.controller.triggerHistory.isEmpty)
                      const Text('No trigger events yet.')
                    else
                      ...widget.controller.triggerHistory.map((event) {
                        final label = event.type == MotionTriggerType.start
                            ? 'START'
                            : 'SPLIT ${event.splitIndex}';
                        return Text(
                          '$label at ${event.triggerMicros}us (score ${event.score.toStringAsFixed(4)})',
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewCard(CameraController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return const Card(
        child: SizedBox(
          height: 200,
          child: Center(child: Text('Camera preview unavailable')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}
