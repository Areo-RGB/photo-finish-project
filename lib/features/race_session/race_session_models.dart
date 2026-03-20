import 'dart:convert';

enum SessionStage { setup, lobby, monitoring }

enum SessionNetworkRole { none, host, client }

enum SessionDeviceRole { unassigned, start, split, stop }

class SessionDevice {
  const SessionDevice({
    required this.id,
    required this.name,
    required this.role,
    required this.isLocal,
  });

  final String id;
  final String name;
  final SessionDeviceRole role;
  final bool isLocal;

  SessionDevice copyWith({
    String? id,
    String? name,
    SessionDeviceRole? role,
    bool? isLocal,
  }) {
    return SessionDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'role': role.name,
      'isLocal': isLocal,
    };
  }

  static SessionDevice? fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }
    final id = source['id']?.toString();
    final name = source['name']?.toString();
    final role = sessionDeviceRoleFromName(source['role']?.toString());
    if (id == null || id.isEmpty || name == null || role == null) {
      return null;
    }
    return SessionDevice(
      id: id,
      name: name,
      role: role,
      isLocal: source['isLocal'] == true,
    );
  }
}

class SessionRaceTimeline {
  const SessionRaceTimeline({
    this.startedAtEpochMs,
    required this.splitMicros,
    this.stopElapsedMicros,
  });

  final int? startedAtEpochMs;
  final List<int> splitMicros;
  final int? stopElapsedMicros;

  factory SessionRaceTimeline.idle() {
    return const SessionRaceTimeline(splitMicros: <int>[]);
  }

  bool get hasStarted => startedAtEpochMs != null;
  bool get hasStopped => stopElapsedMicros != null;
  bool get isRunning => hasStarted && !hasStopped;

  SessionRaceTimeline copyWith({
    int? startedAtEpochMs,
    List<int>? splitMicros,
    int? stopElapsedMicros,
    bool clearStartedAt = false,
    bool clearStopElapsed = false,
  }) {
    return SessionRaceTimeline(
      startedAtEpochMs: clearStartedAt
          ? null
          : (startedAtEpochMs ?? this.startedAtEpochMs),
      splitMicros: splitMicros ?? this.splitMicros,
      stopElapsedMicros: clearStopElapsed
          ? null
          : (stopElapsedMicros ?? this.stopElapsedMicros),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startedAtEpochMs': startedAtEpochMs,
      'splitMicros': splitMicros,
      'stopElapsedMicros': stopElapsedMicros,
    };
  }

  static SessionRaceTimeline fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return SessionRaceTimeline.idle();
    }
    final splitRaw = source['splitMicros'];
    final splitMicros = <int>[];
    if (splitRaw is List) {
      for (final value in splitRaw) {
        if (value is int) {
          splitMicros.add(value);
        } else if (value is num) {
          splitMicros.add(value.toInt());
        }
      }
    }
    final startedAtRaw = source['startedAtEpochMs'];
    final stopElapsedRaw = source['stopElapsedMicros'];
    final startedAtEpochMs = startedAtRaw is num ? startedAtRaw.toInt() : null;
    final stopElapsedMicros = stopElapsedRaw is num
        ? stopElapsedRaw.toInt()
        : null;
    return SessionRaceTimeline(
      startedAtEpochMs: startedAtEpochMs,
      splitMicros: splitMicros,
      stopElapsedMicros: stopElapsedMicros,
    );
  }
}

class SessionSnapshotMessage {
  const SessionSnapshotMessage({
    required this.stage,
    required this.monitoringActive,
    required this.devices,
    required this.timeline,
    this.selfDeviceId,
  });

  final SessionStage stage;
  final bool monitoringActive;
  final List<SessionDevice> devices;
  final SessionRaceTimeline timeline;
  final String? selfDeviceId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': 'snapshot',
      'stage': stage.name,
      'monitoringActive': monitoringActive,
      'devices': devices.map((device) => device.toJson()).toList(),
      'timeline': timeline.toJson(),
      'selfDeviceId': selfDeviceId,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SessionSnapshotMessage? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['type'] != 'snapshot') {
        return null;
      }
      final stage = sessionStageFromName(decoded['stage']?.toString());
      if (stage == null) {
        return null;
      }
      final monitoringActive = decoded['monitoringActive'] == true;
      final devicesRaw = decoded['devices'];
      if (devicesRaw is! List) {
        return null;
      }
      final devices = <SessionDevice>[];
      for (final item in devicesRaw) {
        final parsed = SessionDevice.fromJson(item);
        if (parsed != null) {
          devices.add(parsed);
        }
      }
      if (devices.isEmpty) {
        return null;
      }
      return SessionSnapshotMessage(
        stage: stage,
        monitoringActive: monitoringActive,
        devices: devices,
        timeline: SessionRaceTimeline.fromJson(decoded['timeline']),
        selfDeviceId: decoded['selfDeviceId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class SessionTriggerRequestMessage {
  const SessionTriggerRequestMessage({
    required this.role,
    required this.triggerMicros,
  });

  final SessionDeviceRole role;
  final int triggerMicros;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': 'trigger_request',
      'role': role.name,
      'triggerMicros': triggerMicros,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SessionTriggerRequestMessage? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'trigger_request') {
        return null;
      }
      final role = sessionDeviceRoleFromName(decoded['role']?.toString());
      final triggerMicrosRaw = decoded['triggerMicros'];
      if (role == null || triggerMicrosRaw is! num) {
        return null;
      }
      return SessionTriggerRequestMessage(
        role: role,
        triggerMicros: triggerMicrosRaw.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

SessionStage? sessionStageFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final value in SessionStage.values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

SessionDeviceRole? sessionDeviceRoleFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final value in SessionDeviceRole.values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

String sessionDeviceRoleLabel(SessionDeviceRole role) {
  switch (role) {
    case SessionDeviceRole.unassigned:
      return 'Unassigned';
    case SessionDeviceRole.start:
      return 'Start';
    case SessionDeviceRole.split:
      return 'Split';
    case SessionDeviceRole.stop:
      return 'Stop';
  }
}
