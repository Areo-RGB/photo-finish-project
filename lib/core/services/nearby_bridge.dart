import 'package:flutter/services.dart';

class NearbyEndpoint {
  const NearbyEndpoint({
    required this.id,
    required this.name,
    required this.serviceId,
  });

  final String id;
  final String name;
  final String serviceId;
}

class NearbyBridge {
  static const _methodChannel = MethodChannel(
    'com.paul.sprintsync/nearby_methods',
  );
  static const _eventChannel = EventChannel(
    'com.paul.sprintsync/nearby_events',
  );

  Stream<Map<String, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'type': 'error', 'message': 'Malformed event'};
    });
  }

  Future<Map<String, dynamic>> requestPermissions() async {
    final response = await _methodChannel.invokeMethod<dynamic>(
      'requestPermissions',
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{'granted': false, 'denied': <String>[]};
  }

  Future<void> startHosting({
    required String serviceId,
    required String endpointName,
  }) {
    return _methodChannel.invokeMethod<void>('startHosting', {
      'serviceId': serviceId,
      'endpointName': endpointName,
    });
  }

  Future<void> stopHosting() {
    return _methodChannel.invokeMethod<void>('stopHosting');
  }

  Future<void> startDiscovery({
    required String serviceId,
    required String endpointName,
  }) {
    return _methodChannel.invokeMethod<void>('startDiscovery', {
      'serviceId': serviceId,
      'endpointName': endpointName,
    });
  }

  Future<void> stopDiscovery() {
    return _methodChannel.invokeMethod<void>('stopDiscovery');
  }

  Future<void> requestConnection({
    required String endpointId,
    required String endpointName,
  }) {
    return _methodChannel.invokeMethod<void>('requestConnection', {
      'endpointId': endpointId,
      'endpointName': endpointName,
    });
  }

  Future<void> sendBytes({
    required String endpointId,
    required String messageJson,
  }) {
    return _methodChannel.invokeMethod<void>('sendBytes', {
      'endpointId': endpointId,
      'messageJson': messageJson,
    });
  }

  Future<void> disconnect({required String endpointId}) {
    return _methodChannel.invokeMethod<void>('disconnect', {
      'endpointId': endpointId,
    });
  }

  Future<void> stopAll() {
    return _methodChannel.invokeMethod<void>('stopAll');
  }
}
