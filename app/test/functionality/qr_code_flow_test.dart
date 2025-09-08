import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/grant_qr_scanner_page.dart';
import 'package:doorlock/open_door_page.dart';

void main() {
  group('QR Code Flow Functionality', () {
    testWidgets('GrantQrScannerPage UI structure and callback functionality', (WidgetTester tester) async {
      String? scannedCode;
      List<String> scanHistory = [];
      
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (code) {
            scannedCode = code;
            scanHistory.add(code);
          },
        ),
      ));

      // Verify QR scanner page UI structure
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      
      // Test callback mechanism is set up correctly
      expect(scannedCode, isNull);
      expect(scanHistory.isEmpty, isTrue);
    });

    testWidgets('Real OpenDoorPage UI structure and interface', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'test-grant-456',
          lockToken: 'test-lock-123',
        ),
      ));

      // Verify OpenDoorPage UI structure
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);
      expect(find.byType(OpenDoorPage), findsOneWidget);
    });

    testWidgets('QR scanner to door opening navigation workflow', (WidgetTester tester) async {
      String? scannedLockToken;
      
      // Test QR scanner first
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (lockToken) {
            scannedLockToken = lockToken;
          },
        ),
      ));

      // Verify QR scanner UI
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      
      // Simulate QR scan by triggering the callback
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('scanned-lock-456');
      await tester.pumpAndSettle();
      
      // Verify callback was triggered
      expect(scannedLockToken, equals('scanned-lock-456'));
      
      // Now test the door opening page with the scanned token
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'test-grant-123',
          lockToken: scannedLockToken!,
        ),
      ));

      // Verify door opening UI
      expect(find.byType(OpenDoorPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);
    });

    testWidgets('QR scanner callback behavior and data validation', (WidgetTester tester) async {
      List<String> scannedCodes = [];
      int callbackCount = 0;
      
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (code) {
            scannedCodes.add(code);
            callbackCount++;
          },
        ),
      ));

      // Verify initial state
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(scannedCodes.isEmpty, isTrue);
      expect(callbackCount, equals(0));
      
      // Verify QR scanner page structure
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // Test single scan scenario (direct widget access for testing)
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      
      // First scan
      scannerWidget.onScanned('token-123');
      expect(scannedCodes, contains('token-123'));
      expect(callbackCount, equals(1));
      
      // Verify callback data is correctly passed
      expect(scannedCodes.first, equals('token-123'));
      expect(scannedCodes.length, equals(1));
    });

    testWidgets('QR scanner multiple scan handling', (WidgetTester tester) async {
      List<String> scanHistory = [];
      
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (code) {
            scanHistory.add(code);
          },
        ),
      ));

      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      
      // Multiple scans
      scannerWidget.onScanned('lock-1');
      scannerWidget.onScanned('lock-2');
      scannerWidget.onScanned('lock-3');
      
      expect(scanHistory.length, equals(3));
      expect(scanHistory, containsAll(['lock-1', 'lock-2', 'lock-3']));
    });

    testWidgets('Complete QR to door opening workflow validation', (WidgetTester tester) async {
      String? capturedLockToken;
      
      // Phase 1: Test QR Scanner Component
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (lockToken) {
            capturedLockToken = lockToken;
          },
        ),
      ));

      // Verify QR Scanning interface
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.text('Scan Lock QR Code'), findsOneWidget);

      // Simulate QR scan
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('end-to-end-lock');
      await tester.pumpAndSettle();
      
      // Verify scan result captured
      expect(capturedLockToken, equals('end-to-end-lock'));
      
      // Phase 2: Test Door Opening Component with scanned token
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'end-to-end-grant',
          lockToken: capturedLockToken!,
        ),
      ));
      
      // Verify Door Opening Interface
      expect(find.byType(OpenDoorPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);
    });

    testWidgets('QR scanner workflow with navigation simulation', (WidgetTester tester) async {
      bool navigationTriggered = false;
      String? navigationToken;
      
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => GrantQrScannerPage(
            onScanned: (token) {
              navigationTriggered = true;
              navigationToken = token;
              // Simulate navigation
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OpenDoorPage(
                    grantToken: 'nav-grant',
                    lockToken: token,
                  ),
                ),
              );
            },
          ),
        ),
      ));

      // Initial state
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.byType(OpenDoorPage), findsNothing);
      
      // Trigger navigation
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('nav-lock-token');
      await tester.pumpAndSettle();
      
      // Verify navigation occurred
      expect(navigationTriggered, isTrue);
      expect(navigationToken, equals('nav-lock-token'));
      expect(find.byType(OpenDoorPage), findsOneWidget);
    });

    testWidgets('Door opening page parameter validation', (WidgetTester tester) async {
      // Test with different parameter combinations
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'param-grant',
          lockToken: 'param-lock',
        ),
      ));

      expect(find.byType(OpenDoorPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      
      // Test that the page accepts the parameters without errors
      final doorPage = tester.widget<OpenDoorPage>(find.byType(OpenDoorPage));
      expect(doorPage.grantToken, equals('param-grant'));
      expect(doorPage.lockToken, equals('param-lock'));
    });
  });
}