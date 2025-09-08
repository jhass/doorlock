import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:doorlock/grant_qr_scanner_page.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:doorlock/pb.dart';

// Mock PocketBase that matches the real interface
class MockPocketBase extends PocketBase {
  MockPocketBase() : super('http://localhost:8090');
  
  final Map<String, dynamic> _responses = {};
  Exception? _nextError;
  
  void setResponse(String path, dynamic response) {
    _responses[path] = response;
  }
  
  void setNextError(Exception error) {
    _nextError = error;
  }
  
  @override
  Future<T> send<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    List<http.MultipartFile>? files,
  }) async {
    // Add a small delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 10));
    
    if (_nextError != null) {
      final error = _nextError!;
      _nextError = null;
      throw error;
    }
    
    final key = '$method:$path';
    if (_responses.containsKey(key)) {
      return _responses[key] as T;
    }
    
    return {'success': true} as T;
  }
}



void main() {
  group('QR Code Flow Functionality', () {
    late MockPocketBase mockPB;
    
    setUp(() {
      mockPB = MockPocketBase();
      // Inject mock PocketBase into the real PB class
      PB.setTestInstance(mockPB);
    });
    
    tearDown(() {
      // Clear the test instance to restore normal operation
      PB.clearTestInstance();
    });

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

    testWidgets('Real OpenDoorPage functionality with success response', (WidgetTester tester) async {
      // Setup successful door opening response
      mockPB.setResponse('POST:/doorlock/locks/test-lock-123/open', {'success': true});
      
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

      // Test door opening operation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump(); // Start the async operation
      
      // Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle(); // Complete async operation
      
      // Should show success message
      expect(find.text('Door opened!'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Real OpenDoorPage error handling', (WidgetTester tester) async {
      // Setup error response
      mockPB.setNextError(ClientException(
        statusCode: 400,
        response: {'message': 'Invalid grant token'},
      ));
      
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'invalid-grant',
          lockToken: 'test-lock-123',
        ),
      ));

      // Test door opening with error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('Failed: Invalid grant token'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('QR scanner to door opening navigation workflow', (WidgetTester tester) async {
      // Setup successful door opening response
      mockPB.setResponse('POST:/doorlock/locks/scanned-lock-456/open', {'success': true});
      
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

      // Test door opening functionality
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      expect(find.text('Door opened!'), findsOneWidget);
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

    testWidgets('Real OpenDoorPage multiple operations and loading states', (WidgetTester tester) async {
      // Setup response for multiple operations
      mockPB.setResponse('POST:/doorlock/locks/multi-test/open', {'success': true});
      
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'multi-grant',
          lockToken: 'multi-test',
        ),
      ));

      // Verify button is enabled initially
      final button = find.widgetWithText(ElevatedButton, 'Open Door');
      expect(button, findsOneWidget);

      // First operation
      await tester.tap(button);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      expect(find.text('Door opened!'), findsOneWidget);
      
      // Second operation should clear previous result and show loading again
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Door opened!'), findsNothing); // Result should be cleared
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      expect(find.text('Door opened!'), findsOneWidget);
    });

    testWidgets('QR scanner error handling workflow', (WidgetTester tester) async {
      // Setup network error
      mockPB.setNextError(ClientException(
        statusCode: 500,
        response: {'message': 'Server error'},
      ));
      
      String? scannedLockToken;
      
      // Test QR scanner
      await tester.pumpWidget(MaterialApp(
        home: GrantQrScannerPage(
          onScanned: (lockToken) {
            scannedLockToken = lockToken;
          },
        ),
      ));

      // Start with QR scanner
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      
      // Scan QR code
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('error-lock-token');
      await tester.pumpAndSettle();
      
      expect(scannedLockToken, equals('error-lock-token'));
      
      // Now test door opening with error
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'error-test-grant',
          lockToken: scannedLockToken!,
        ),
      ));
      
      // Verify OpenDoorPage
      expect(find.byType(OpenDoorPage), findsOneWidget);
      
      // Try to open door - should fail
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('Failed: Server error'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Complete QR to door opening workflow validation', (WidgetTester tester) async {
      // Setup successful responses for the complete workflow
      mockPB.setResponse('POST:/doorlock/locks/end-to-end-lock/open', {'success': true});
      
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

      // Phase 3: Test Door Opening Operation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      // Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      // Phase 4: Verify Success State
      expect(find.text('Door opened!'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget); // Button should still be available
    });
  });
}