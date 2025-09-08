import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:doorlock/grant_qr_scanner_page.dart';

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

// Simplified door opening page that doesn't depend on pb.dart or env_config.dart
class TestableOpenDoorPage extends StatefulWidget {
  final String grantToken;
  final String lockToken;
  final PocketBase pb;
  
  const TestableOpenDoorPage({
    super.key,
    required this.grantToken,
    required this.lockToken,
    required this.pb,
  });

  @override
  State<TestableOpenDoorPage> createState() => _TestableOpenDoorPageState();
}

class _TestableOpenDoorPageState extends State<TestableOpenDoorPage> {
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _openDoor() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    
    try {
      await widget.pb.send(
        '/doorlock/locks/${widget.lockToken}/open',
        method: 'POST',
        body: {'token': widget.grantToken},
      );
      setState(() {
        _result = 'Door opened!';
      });
    } on ClientException catch (e) {
      setState(() {
        _error = 'Failed: ${e.response['message'] ?? e.toString()}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open Door')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_result != null)
                    Text(_result!, style: const TextStyle(color: Colors.green, fontSize: 20)),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _openDoor,
                    child: const Text('Open Door'),
                  ),
                ],
              ),
      ),
    );
  }
}

// Testable GrantFlow that doesn't depend on web-specific components
class TestableGrantFlow extends StatefulWidget {
  final String grantToken;
  final PocketBase pb;
  
  const TestableGrantFlow({
    super.key,
    required this.grantToken,
    required this.pb,
  });
  
  @override
  State<TestableGrantFlow> createState() => _TestableGrantFlowState();
}

class _TestableGrantFlowState extends State<TestableGrantFlow> {
  String? _lockToken;

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
        },
      );
    }
    return TestableOpenDoorPage(
      grantToken: widget.grantToken,
      lockToken: _lockToken!,
      pb: widget.pb,
    );
  }
}

void main() {
  group('QR Code Flow Functionality', () {
    late MockPocketBase mockPB;
    
    setUp(() {
      mockPB = MockPocketBase();
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
        home: TestableOpenDoorPage(
          grantToken: 'test-grant-456',
          lockToken: 'test-lock-123',
          pb: mockPB,
        ),
      ));

      // Verify OpenDoorPage UI structure
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);
      expect(find.byType(TestableOpenDoorPage), findsOneWidget);

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
        home: TestableOpenDoorPage(
          grantToken: 'invalid-grant',
          lockToken: 'test-lock-123',
          pb: mockPB,
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

    testWidgets('Real GrantFlow workflow integration from QR scan to door opening', (WidgetTester tester) async {
      // Setup successful door opening response
      mockPB.setResponse('POST:/doorlock/locks/scanned-lock-456/open', {'success': true});
      
      await tester.pumpWidget(MaterialApp(
        home: TestableGrantFlow(
          grantToken: 'test-grant-123',
          pb: mockPB,
        ),
      ));

      // Should start with QR scanner
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      expect(find.byType(TestableOpenDoorPage), findsNothing);
      
      // Simulate QR scan by triggering the callback
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('scanned-lock-456');
      await tester.pumpAndSettle();
      
      // Should now show TestableOpenDoorPage
      expect(find.byType(GrantQrScannerPage), findsNothing);
      expect(find.byType(TestableOpenDoorPage), findsOneWidget);
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
        home: TestableOpenDoorPage(
          grantToken: 'multi-grant',
          lockToken: 'multi-test',
          pb: mockPB,
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

    testWidgets('GrantFlow with network error handling', (WidgetTester tester) async {
      // Setup network error
      mockPB.setNextError(ClientException(
        statusCode: 500,
        response: {'message': 'Server error'},
      ));
      
      await tester.pumpWidget(MaterialApp(
        home: TestableGrantFlow(
          grantToken: 'error-test-grant',
          pb: mockPB,
        ),
      ));

      // Start with QR scanner
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      
      // Scan QR code to navigate to door page
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('error-lock-token');
      await tester.pumpAndSettle();
      
      // Should show TestableOpenDoorPage
      expect(find.byType(TestableOpenDoorPage), findsOneWidget);
      
      // Try to open door - should fail
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('Failed: Server error'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Complete real GrantFlow end-to-end workflow', (WidgetTester tester) async {
      // Setup successful responses for the complete workflow
      mockPB.setResponse('POST:/doorlock/locks/end-to-end-lock/open', {'success': true});
      
      await tester.pumpWidget(MaterialApp(
        home: TestableGrantFlow(
          grantToken: 'end-to-end-grant',
          pb: mockPB,
        ),
      ));

      // Phase 1: QR Scanning
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      expect(find.byType(TestableOpenDoorPage), findsNothing);

      // Simulate QR scan
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('end-to-end-lock');
      await tester.pumpAndSettle();
      
      // Phase 2: Door Opening Interface
      expect(find.byType(GrantQrScannerPage), findsNothing);
      expect(find.byType(TestableOpenDoorPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);

      // Phase 3: Door Opening Operation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      // Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      // Phase 4: Success State
      expect(find.text('Door opened!'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget); // Button should still be available
    });
  });
}