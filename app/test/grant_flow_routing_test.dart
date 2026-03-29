import 'package:doorlock/grant_token_encoder.dart';
import 'package:doorlock/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns no grant decision when query is missing', () {
    final decision = resolveGrantRoute(null);

    expect(decision, isA<NoGrantRouteDecision>());
  });

  test('returns invalid decision when query is empty', () {
    final decision = resolveGrantRoute('');

    expect(decision, isA<InvalidGrantRouteDecision>());
  });

  test('returns scan-required decision for typed scan payload', () {
    const grant = '00112233445566778899aabbccddeeff';
    final encoded = GrantTokenEncoder.encodeScanRequired(grant);

    final decision = resolveGrantRoute(encoded);

    expect(decision, isA<ScanRequiredRouteDecision>());
    expect((decision as ScanRequiredRouteDecision).grantToken, grant);
  });

  test('returns no-scan decision for typed no-scan payload', () {
    const grant = '00112233445566778899aabbccddeeff';
    const lock = 'ffeeddccbbaa99887766554433221100';
    final encoded = GrantTokenEncoder.encodeNoScan(grant, lock);

    final decision = resolveGrantRoute(encoded);

    expect(decision, isA<NoScanRouteDecision>());
    expect((decision as NoScanRouteDecision).grantToken, grant);
    expect((decision).lockToken, lock);
  });

  test('returns invalid decision for malformed typed payload', () {
    final decision = resolveGrantRoute('!not_base64!');

    expect(decision, isA<InvalidGrantRouteDecision>());
  });
}
