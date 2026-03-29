import 'package:doorlock/grant_token_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips scan-required payload', () {
    const grant = '00112233445566778899aabbccddeeff';
    final encoded = GrantTokenEncoder.encodeScanRequired(grant);
    final payload = GrantTokenEncoder.decode(encoded);

    expect(payload, isA<ScanRequiredPayload>());
    expect((payload as ScanRequiredPayload).grantToken, grant);
  });

  test('round-trips no-scan payload', () {
    const grant = '00112233445566778899aabbccddeeff';
    const lock = 'ffeeddccbbaa99887766554433221100';
    final encoded = GrantTokenEncoder.encodeNoScan(grant, lock);
    final payload = GrantTokenEncoder.decode(encoded);

    expect(payload, isA<NoScanPayload>());
    expect((payload as NoScanPayload).grantToken, grant);
    expect((payload).lockToken, lock);
  });

  test('throws on malformed base64url payload', () {
    expect(() => GrantTokenEncoder.decode('!not_base64!'), throwsFormatException);
  });

  test('throws on syntactically valid base64url payload with invalid length', () {
    // "AQIDBAU" decodes to exactly 5 bytes: [0x01, 0x02, 0x03, 0x04, 0x05].
    const fiveBytePayload = 'AQIDBAU';
    expect(() => GrantTokenEncoder.decode(fiveBytePayload), throwsFormatException);
  });

  test('throws on unsupported payload type byte', () {
    // 0x03 + 16 zero bytes => 17-byte payload with unknown type.
    const unsupported = 'AwAAAAAAAAAAAAAAAAAAAAA';
    expect(() => GrantTokenEncoder.decode(unsupported), throwsFormatException);
  });
}