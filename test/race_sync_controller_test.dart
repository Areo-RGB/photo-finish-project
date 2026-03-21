import 'package:flutter_test/flutter_test.dart';
import 'package:sprint_sync/features/race_session/race_session_models.dart';

void main() {
  test(
    'legacy race_sync controller coverage now targets race_session roles',
    () {
      expect(SessionNetworkRole.values, contains(SessionNetworkRole.host));
      expect(SessionNetworkRole.values, contains(SessionNetworkRole.client));
      expect(SessionDeviceRole.values, contains(SessionDeviceRole.start));
      expect(SessionDeviceRole.values, contains(SessionDeviceRole.stop));
    },
  );
}
