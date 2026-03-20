import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprint_sync/core/repositories/local_repository.dart';
import 'package:sprint_sync/core/services/nearby_bridge.dart';
import 'package:sprint_sync/features/motion_detection/motion_detection_controller.dart';
import 'package:sprint_sync/features/race_session/race_session_controller.dart';
import 'package:sprint_sync/features/race_session/race_session_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('setup requires at least two devices before Next is enabled', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();

    expect(fixture.controller.totalDeviceCount, 1);
    expect(fixture.controller.canGoToLobby, isFalse);

    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'peer-1',
      'connected': true,
    });
    await _flushEvents();

    expect(fixture.controller.totalDeviceCount, 2);
    expect(fixture.controller.canGoToLobby, isTrue);

    fixture.dispose();
  });

  test('createLobby sets host role and joinLobby sets client role', () async {
    final hostFixture = _ControllerFixture.create();
    await hostFixture.controller.createLobby();
    expect(hostFixture.controller.isHost, isTrue);
    hostFixture.dispose();

    final clientFixture = _ControllerFixture.create();
    await clientFixture.controller.joinLobby();
    expect(clientFixture.controller.isClient, isTrue);
    clientFixture.dispose();
  });

  test('host assigns roles and START uniqueness is enforced', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();
    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'peer-1',
      'connected': true,
    });
    await _flushEvents();
    fixture.controller.goToLobby();

    fixture.controller.assignRole('local-device', SessionDeviceRole.start);
    fixture.controller.assignRole('peer-1', SessionDeviceRole.stop);
    expect(_roleOf(fixture.controller, 'local-device'), SessionDeviceRole.start);
    expect(_roleOf(fixture.controller, 'peer-1'), SessionDeviceRole.stop);

    fixture.controller.assignRole('peer-1', SessionDeviceRole.start);
    expect(_roleOf(fixture.controller, 'peer-1'), SessionDeviceRole.start);
    expect(
      _roleOf(fixture.controller, 'local-device'),
      SessionDeviceRole.unassigned,
    );

    fixture.dispose();
  });

  test('two-device lobby disallows split role assignment', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();
    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'peer-1',
      'connected': true,
    });
    await _flushEvents();
    fixture.controller.goToLobby();

    fixture.controller.assignRole('local-device', SessionDeviceRole.split);
    expect(
      _roleOf(fixture.controller, 'local-device'),
      SessionDeviceRole.unassigned,
    );
    expect(fixture.controller.canShowSplitControls, isFalse);

    fixture.dispose();
  });

  test('multiple split roles are supported and append split timeline events', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();
    for (final endpointId in <String>['peer-1', 'peer-2', 'peer-3']) {
      fixture.bridge.emitEvent(<String, dynamic>{
        'type': 'connection_result',
        'endpointId': endpointId,
        'connected': true,
      });
    }
    await _flushEvents();
    fixture.controller.goToLobby();

    fixture.controller.assignRole('local-device', SessionDeviceRole.start);
    fixture.controller.assignRole('peer-1', SessionDeviceRole.stop);
    fixture.controller.assignRole('peer-2', SessionDeviceRole.split);
    fixture.controller.assignRole('peer-3', SessionDeviceRole.split);

    await fixture.controller.triggerManualEvent(SessionDeviceRole.start);
    await fixture.controller.triggerManualEvent(SessionDeviceRole.split);
    await fixture.controller.triggerManualEvent(SessionDeviceRole.split);
    await fixture.controller.triggerManualEvent(SessionDeviceRole.stop);

    expect(fixture.controller.timeline.hasStarted, isTrue);
    expect(fixture.controller.timeline.splitMicros.length, 2);
    expect(fixture.controller.timeline.stopElapsedMicros, isNotNull);

    fixture.dispose();
  });

  test('client cannot trigger host-only lobby race actions', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.joinLobby();
    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'host-1',
      'connected': true,
    });
    await _flushEvents();
    fixture.controller.goToLobby();

    await fixture.controller.triggerManualEvent(SessionDeviceRole.start);
    expect(fixture.controller.timeline.hasStarted, isFalse);

    fixture.dispose();
  });

  test('roles are locked during monitoring', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();
    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'peer-1',
      'connected': true,
    });
    await _flushEvents();
    fixture.controller.goToLobby();

    fixture.controller.assignRole('local-device', SessionDeviceRole.start);
    fixture.controller.assignRole('peer-1', SessionDeviceRole.stop);
    await fixture.controller.startMonitoring();

    final before = _roleOf(fixture.controller, 'peer-1');
    fixture.controller.assignRole('peer-1', SessionDeviceRole.start);
    final after = _roleOf(fixture.controller, 'peer-1');

    expect(fixture.controller.monitoringActive, isTrue);
    expect(fixture.controller.stage, SessionStage.monitoring);
    expect(after, before);

    fixture.dispose();
  });

  test('stopMonitoring returns to lobby and preserves device roles', () async {
    final fixture = _ControllerFixture.create();
    await fixture.controller.createLobby();
    fixture.bridge.emitEvent(<String, dynamic>{
      'type': 'connection_result',
      'endpointId': 'peer-1',
      'connected': true,
    });
    await _flushEvents();
    fixture.controller.goToLobby();

    fixture.controller.assignRole('local-device', SessionDeviceRole.start);
    fixture.controller.assignRole('peer-1', SessionDeviceRole.stop);
    await fixture.controller.startMonitoring();
    await fixture.controller.stopMonitoring();

    expect(fixture.controller.stage, SessionStage.lobby);
    expect(fixture.controller.monitoringActive, isFalse);
    expect(_roleOf(fixture.controller, 'local-device'), SessionDeviceRole.start);
    expect(_roleOf(fixture.controller, 'peer-1'), SessionDeviceRole.stop);

    fixture.dispose();
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(const Duration(milliseconds: 1));
}

SessionDeviceRole _roleOf(RaceSessionController controller, String deviceId) {
  final match = controller.devices.firstWhere((device) => device.id == deviceId);
  return match.role;
}

class _ControllerFixture {
  _ControllerFixture({
    required this.bridge,
    required this.motionController,
    required this.controller,
  });

  final _FakeNearbyBridge bridge;
  final MotionDetectionController motionController;
  final RaceSessionController controller;

  factory _ControllerFixture.create() {
    final bridge = _FakeNearbyBridge();
    final motionController = MotionDetectionController(
      repository: LocalRepository(),
    );
    final controller = RaceSessionController(
      nearbyBridge: bridge,
      motionController: motionController,
      startMonitoringAction: () async {},
      stopMonitoringAction: () async {},
    );
    return _ControllerFixture(
      bridge: bridge,
      motionController: motionController,
      controller: controller,
    );
  }

  void dispose() {
    controller.dispose();
    motionController.dispose();
    bridge.dispose();
  }
}

class _FakeNearbyBridge extends NearbyBridge {
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void emitEvent(Map<String, dynamic> event) {
    _eventsController.add(event);
  }

  @override
  Future<Map<String, dynamic>> requestPermissions() async {
    return <String, dynamic>{'granted': true, 'denied': <String>[]};
  }

  @override
  Future<void> startHosting({
    required String serviceId,
    required String endpointName,
  }) async {}

  @override
  Future<void> startDiscovery({
    required String serviceId,
    required String endpointName,
  }) async {}

  @override
  Future<void> requestConnection({
    required String endpointId,
    required String endpointName,
  }) async {}

  @override
  Future<void> sendBytes({
    required String endpointId,
    required String messageJson,
  }) async {}

  @override
  Future<void> disconnect({required String endpointId}) async {}

  @override
  Future<void> stopAll() async {}

  void dispose() {
    _eventsController.close();
  }
}
