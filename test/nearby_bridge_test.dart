import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprint_sync/core/services/nearby_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.paul.sprintsync/nearby_methods');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('startHosting defaults to star strategy payload', () async {
    final bridge = NearbyBridge();

    await bridge.startHosting(serviceId: 'service-id', endpointName: 'host');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'startHosting');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['serviceId'], 'service-id');
    expect(args['endpointName'], 'host');
    expect(args['strategy'], 'star');
  });

  test('startHosting forwards point_to_point strategy payload', () async {
    final bridge = NearbyBridge();

    await bridge.startHosting(
      serviceId: 'service-id',
      endpointName: 'host',
      strategy: NearbyConnectionStrategy.pointToPoint,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'startHosting');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['strategy'], 'point_to_point');
  });

  test('startDiscovery forwards point_to_point strategy payload', () async {
    final bridge = NearbyBridge();

    await bridge.startDiscovery(
      serviceId: 'service-id',
      endpointName: 'client',
      strategy: NearbyConnectionStrategy.pointToPoint,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'startDiscovery');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['serviceId'], 'service-id');
    expect(args['endpointName'], 'client');
    expect(args['strategy'], 'point_to_point');
  });
}
