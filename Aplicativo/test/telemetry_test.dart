import 'package:flutter_test/flutter_test.dart';
import 'package:lixeira_inteligente/features/telemetry/domain/telemetry.dart';

void main() {
  test('parses telemetry payload', () {
    final t = Telemetry.fromJson({'deviceId':'LIXEIRA-01','weightGrams':125.5,'metalDetected':true,'presence':true,'fillLevel':40.0,'gate':'closed','network':'wifi','rssi':-55});
    expect(t.deviceId, 'LIXEIRA-01');
    expect(t.metalDetected, isTrue);
    expect(t.weightGrams, 125.5);
  });
}
