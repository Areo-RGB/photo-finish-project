import 'package:flutter/material.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_controller.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_screen.dart';
import 'package:sprint_sync/features/race_session/race_session_controller.dart';
import 'package:sprint_sync/features/race_session/race_session_models.dart';

class RaceSessionScreen extends StatelessWidget {
  const RaceSessionScreen({
    super.key,
    required this.controller,
    required this.motionController,
  });

  final RaceSessionController controller;
  final MotionDetectionController motionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, motionController]),
      builder: (context, child) {
        switch (controller.stage) {
          case SessionStage.setup:
            return _buildSetupScaffold(context);
          case SessionStage.lobby:
            return _buildLobbyScaffold(context);
          case SessionStage.monitoring:
            return _buildMonitoringScaffold(context);
        }
      },
    );
  }

  Widget _buildSetupScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup: Connection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Network role: ${controller.networkRole.name}'),
                  Text('Devices connected: ${controller.totalDeviceCount}'),
                  Text('Permissions granted: ${controller.permissionsGranted}'),
                  if (controller.errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : controller.requestPermissions,
                        child: const Text('Request Permissions'),
                      ),
                      FilledButton(
                        onPressed: controller.busy ? null : controller.createLobby,
                        child: const Text('Create Lobby'),
                      ),
                      FilledButton(
                        onPressed: controller.busy ? null : controller.joinLobby,
                        child: const Text('Join Lobby'),
                      ),
                      FilledButton(
                        onPressed: controller.canGoToLobby
                            ? controller.goToLobby
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
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
                    'Discovered Devices',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (controller.discoveredEndpoints.isEmpty)
                    const Text('No discovered devices yet.')
                  else
                    ...controller.discoveredEndpoints.map((endpoint) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(endpoint.name),
                        subtitle: Text(endpoint.id),
                        trailing: TextButton(
                          onPressed: () => controller.connect(endpoint.id),
                          child: const Text('Connect'),
                        ),
                      );
                    }),
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
                    'Connected Devices',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...controller.devices.map((device) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        device.isLocal ? '${device.name} (Local)' : device.name,
                      ),
                      subtitle: Text(device.id),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Roles',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Host controls role assignments and race actions.'),
                  Text('Devices connected: ${controller.totalDeviceCount}'),
                  const SizedBox(height: 12),
                  ...controller.devices.map((device) {
                    return _buildRoleRow(device);
                  }),
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
                    'Race Controls',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: controller.isHost
                            ? () => controller.triggerManualEvent(
                                SessionDeviceRole.start,
                              )
                            : null,
                        child: const Text('Start'),
                      ),
                      if (controller.canShowSplitControls)
                        FilledButton(
                          onPressed: controller.isHost
                              ? () => controller.triggerManualEvent(
                                  SessionDeviceRole.split,
                                )
                              : null,
                          child: const Text('Split'),
                        ),
                      FilledButton(
                        onPressed: controller.isHost
                            ? () => controller.triggerManualEvent(
                                SessionDeviceRole.stop,
                              )
                            : null,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.canStartMonitoring
                        ? controller.startMonitoring
                        : null,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Start Monitoring'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTimelineCard(),
        ],
      ),
    );
  }

  Widget _buildMonitoringScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        actions: [
          TextButton(
            onPressed: controller.isHost ? controller.stopMonitoring : null,
            child: const Text('Stop Monitoring'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local role: ${sessionDeviceRoleLabel(controller.localRole)}'),
                    const SizedBox(height: 4),
                    const Text('Roles are locked while monitoring is active.'),
                    if (!controller.isHost)
                      const Text('Waiting for host to stop monitoring.'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: MotionDetectionScreen(
              controller: motionController,
              showPreview: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRow(SessionDevice device) {
    final canEdit = controller.isHost && !controller.monitoringActive;
    final allRoles = <SessionDeviceRole>[
      SessionDeviceRole.unassigned,
      SessionDeviceRole.start,
      if (controller.canShowSplitControls) SessionDeviceRole.split,
      SessionDeviceRole.stop,
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(device.isLocal ? '${device.name} (Local)' : device.name),
      subtitle: Text(device.id),
      trailing: canEdit
          ? PopupMenuButton<SessionDeviceRole>(
              onSelected: (value) => controller.assignRole(device.id, value),
              itemBuilder: (context) => allRoles.map((role) {
                return PopupMenuItem<SessionDeviceRole>(
                  value: role,
                  child: Text(sessionDeviceRoleLabel(role)),
                );
              }).toList(),
              child: Chip(label: Text(sessionDeviceRoleLabel(device.role))),
            )
          : Text(sessionDeviceRoleLabel(device.role)),
    );
  }

  Widget _buildTimelineCard() {
    final timeline = controller.timeline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Started: ${timeline.startedAtEpochMs ?? '-'}'),
            Text('Splits: ${timeline.splitMicros.length}'),
            if (timeline.splitMicros.isNotEmpty)
              ...timeline.splitMicros.asMap().entries.map((entry) {
                return Text('Split ${entry.key + 1}: ${entry.value}us');
              }),
            Text('Stopped: ${timeline.stopElapsedMicros ?? '-'}'),
          ],
        ),
      ),
    );
  }

}
