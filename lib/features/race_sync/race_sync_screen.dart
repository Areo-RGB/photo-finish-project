import 'package:flutter/material.dart';
import 'package:sprint_sync/features/race_sync/race_sync_controller.dart';

class RaceSyncScreen extends StatelessWidget {
  const RaceSyncScreen({super.key, required this.controller});

  final RaceSyncController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearby Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Role: ${controller.role.name}'),
                    Text(
                      'Permissions granted: ${controller.permissionsGranted}',
                    ),
                    const SizedBox(height: 8),
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
                          onPressed: controller.busy
                              ? null
                              : controller.startHosting,
                          child: const Text('Host Session'),
                        ),
                        FilledButton(
                          onPressed: controller.busy
                              ? null
                              : controller.startDiscovery,
                          child: const Text('Find Hosts'),
                        ),
                        OutlinedButton(
                          onPressed: controller.stopAll,
                          child: const Text('Stop All'),
                        ),
                      ],
                    ),
                    if (controller.errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        controller.errorText!,
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
                    const Text(
                      'Discovered Endpoints',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (controller.discoveredEndpoints.isEmpty)
                      const Text('No endpoints discovered yet.')
                    else
                      ...controller.discoveredEndpoints.map((endpoint) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(endpoint.name),
                          subtitle: Text(endpoint.id),
                          trailing: TextButton(
                            onPressed: () =>
                                controller.requestConnection(endpoint.id),
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
                    if (controller.connectedEndpointIds.isEmpty)
                      const Text('No active connections.')
                    else
                      ...controller.connectedEndpointIds.map((endpointId) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(endpointId),
                          trailing: TextButton(
                            onPressed: () => controller.disconnect(endpointId),
                            child: const Text('Disconnect'),
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
                      'Race State',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Race started: ${controller.sessionState.raceStarted}',
                    ),
                    Text(
                      'Started at: ${controller.sessionState.startedAtEpochMs ?? '-'}',
                    ),
                    Text(
                      'Splits: ${controller.sessionState.splitMicros.length}',
                    ),
                    ...controller.sessionState.splitMicros.asMap().entries.map((
                      entry,
                    ) {
                      return Text('Split ${entry.key + 1}: ${entry.value}us');
                    }),
                    const Divider(),
                    const Text(
                      'Last Saved Run',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      controller.lastRun == null
                          ? 'No saved run yet.'
                          : 'Started ${controller.lastRun!.startedAtEpochMs}, '
                                'splits ${controller.lastRun!.splitMicros.length}',
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
                      'Event Log',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (controller.logs.isEmpty)
                      const Text('No events yet.')
                    else
                      ...controller.logs.take(20).map(Text.new),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
