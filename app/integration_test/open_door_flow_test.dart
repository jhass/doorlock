import 'package:doorlock/grant_qr_scanner_page.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const grantToken = String.fromEnvironment('TEST_GRANT_TOKEN');
  const lockToken = String.fromEnvironment('TEST_LOCK_TOKEN');
  const pbUrl = String.fromEnvironment('POCKETBASE_URL');

  testWidgets('grantee flow: scan -> open door -> success', (tester) async {
    await tester.pumpWidget(
      PBScope(
        pb: PocketBase(pbUrl),
        child: MaterialApp(
          home: GrantQrScannerPage(
            onScanned: (token) {
              Navigator.of(tester.element(find.byType(GrantQrScannerPage)))
                  .pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => OpenDoorPage(
                        grantToken: grantToken,
                        lockToken: token,
                      ),
                    ),
                  );
            },
            scannerBuilder: (onDetect) => ElevatedButton(
              key: const Key('simulate_scan'),
              onPressed: () =>
                  onDetect(BarcodeCapture(barcodes: [Barcode(rawValue: lockToken)])),
              child: const Text('Simulate Scan'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('simulate_scan')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
    await tester.pumpAndSettle();

    expect(find.text('Door opened!'), findsOneWidget);
  });
}
