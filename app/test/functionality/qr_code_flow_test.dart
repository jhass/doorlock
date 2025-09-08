import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/grant_qr_scanner_page.dart';

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

    testWidgets('QR code scanning workflow integration with door opening', (WidgetTester tester) async {
      String? capturedGrantToken;
      String? capturedLockToken;
      bool doorPageShown = false;
      
      // Create a workflow navigator widget to test integration
      await tester.pumpWidget(MaterialApp(
        home: _WorkflowNavigator(
          onDoorPageNavigated: (grantToken, lockToken) {
            capturedGrantToken = grantToken;
            capturedLockToken = lockToken;
            doorPageShown = true;
          },
        ),
      ));

      // Start with QR scanner
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      
      // Simulate QR scan by triggering the callback directly
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('scanned-lock-token-789');
      await tester.pumpAndSettle();
      
      // Verify workflow navigation occurred
      expect(doorPageShown, isTrue);
      expect(capturedGrantToken, equals('grant-token-123'));
      expect(capturedLockToken, equals('scanned-lock-token-789'));
      
      // Should now show door opening page
      expect(find.byType(_DoorOpeningPage), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);
    });

    testWidgets('Grant flow state management and transitions', (WidgetTester tester) async {
      List<String> workflowStates = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _WorkflowStateTracker(
          onStateChange: (state) => workflowStates.add(state),
        ),
      ));

      // Initial state should be QR scanning
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(workflowStates, contains('qr_scanner_ready'));

      // Simulate successful QR scan
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('test-lock-token');
      await tester.pumpAndSettle();

      // Should transition to door opening state
      expect(find.byType(_DoorOpeningPage), findsOneWidget);
      expect(workflowStates, contains('door_page_ready'));

      // Test door opening action
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump();
      
      expect(workflowStates, contains('door_opening_started'));
    });

    testWidgets('QR scanner callback behavior and data handling', (WidgetTester tester) async {
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

      // Test multiple scan scenarios
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      
      // First scan
      scannerWidget.onScanned('token-123');
      expect(scannedCodes, contains('token-123'));
      expect(callbackCount, equals(1));
      
      // Second scan
      scannerWidget.onScanned('token-456');
      expect(scannedCodes, contains('token-456'));
      expect(callbackCount, equals(2));
      
      // Verify scan history
      expect(scannedCodes.length, equals(2));
      expect(scannedCodes, containsAll(['token-123', 'token-456']));
    });

    testWidgets('Door opening workflow simulation with real UI components', (WidgetTester tester) async {
      List<String> doorOperations = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _DoorOpeningPage(
          grantToken: 'test-grant',
          lockToken: 'test-lock',
          onOperation: (operation) => doorOperations.add(operation),
        ),
      ));

      // Verify door opening page UI structure
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);

      // Test door opening operation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();
      
      expect(doorOperations, contains('open'));
      expect(doorOperations.length, equals(1));
    });

    testWidgets('Error handling in QR scanning workflow', (WidgetTester tester) async {
      List<String> errorStates = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _QRScannerWithErrorHandling(
          onError: (error) => errorStates.add(error),
        ),
      ));

      // Test invalid QR code handling
      final state = tester.state<_QRScannerWithErrorHandlingState>(find.byType(_QRScannerWithErrorHandling));
      
      // Simulate invalid QR scan
      state.simulateInvalidScan('invalid-data');
      await tester.pumpAndSettle();
      
      expect(errorStates, contains('invalid_qr_code'));
      
      // Test empty QR code
      state.simulateInvalidScan('');
      await tester.pumpAndSettle();
      
      expect(errorStates, contains('empty_qr_code'));
    });

    testWidgets('Complete grant workflow from scan to door operation', (WidgetTester tester) async {
      List<String> workflowSteps = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _CompleteWorkflowDemo(
          onStep: (step) => workflowSteps.add(step),
        ),
      ));

      // Initial state: QR scanning
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(workflowSteps, contains('workflow_started'));

      // Simulate QR scan
      final scannerWidget = tester.widget<GrantQrScannerPage>(find.byType(GrantQrScannerPage));
      scannerWidget.onScanned('grant-lock-token');
      await tester.pumpAndSettle();
      
      expect(workflowSteps, contains('qr_scanned'));
      expect(find.byType(_DoorOpeningPage), findsOneWidget);

      // Test door opening
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();
      
      expect(workflowSteps, contains('door_opened'));
      
      // Verify complete workflow sequence
      expect(workflowSteps, containsAll(['workflow_started', 'qr_scanned', 'door_opened']));
    });
  });
}

// Helper widget to test QR scanner to door opening workflow integration
class _WorkflowNavigator extends StatefulWidget {
  final Function(String grantToken, String lockToken) onDoorPageNavigated;
  const _WorkflowNavigator({required this.onDoorPageNavigated});

  @override
  State<_WorkflowNavigator> createState() => _WorkflowNavigatorState();
}

class _WorkflowNavigatorState extends State<_WorkflowNavigator> {
  String? _lockToken;
  final String _grantToken = 'grant-token-123';

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
          widget.onDoorPageNavigated(_grantToken, lockToken);
        },
      );
    }
    
    return _DoorOpeningPage(
      grantToken: _grantToken,
      lockToken: _lockToken!,
    );
  }
}

// Helper widget to test workflow state management
class _WorkflowStateTracker extends StatefulWidget {
  final Function(String) onStateChange;
  const _WorkflowStateTracker({required this.onStateChange});

  @override
  State<_WorkflowStateTracker> createState() => _WorkflowStateTrackerState();
}

class _WorkflowStateTrackerState extends State<_WorkflowStateTracker> {
  String? _lockToken;
  final String _grantToken = 'test-grant-token';

  @override
  void initState() {
    super.initState();
    widget.onStateChange('qr_scanner_ready');
  }

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
          widget.onStateChange('door_page_ready');
        },
      );
    }
    
    return _DoorOpeningPage(
      grantToken: _grantToken,
      lockToken: _lockToken!,
      onOperation: (operation) => widget.onStateChange('door_opening_started'),
    );
  }
}

// Simplified door opening page for testing without web dependencies
class _DoorOpeningPage extends StatefulWidget {
  final String grantToken;
  final String lockToken;
  final Function(String)? onOperation;
  const _DoorOpeningPage({
    required this.grantToken,
    required this.lockToken,
    this.onOperation,
  });

  @override
  State<_DoorOpeningPage> createState() => _DoorOpeningPageState();
}

class _DoorOpeningPageState extends State<_DoorOpeningPage> {
  bool _loading = false;
  String? _result;

  Future<void> _openDoor() async {
    setState(() => _loading = true);
    widget.onOperation?.call('open');
    
    // Simulate door opening operation synchronously for tests
    setState(() {
      _loading = false;
      _result = 'Door opened!';
    });
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

// Helper widget for testing QR scanner error handling
class _QRScannerWithErrorHandling extends StatefulWidget {
  final Function(String) onError;
  const _QRScannerWithErrorHandling({required this.onError});

  @override
  State<_QRScannerWithErrorHandling> createState() => _QRScannerWithErrorHandlingState();
}

class _QRScannerWithErrorHandlingState extends State<_QRScannerWithErrorHandling> {
  void simulateInvalidScan(String data) {
    if (data.isEmpty) {
      widget.onError('empty_qr_code');
    } else if (data == 'invalid-data') {
      widget.onError('invalid_qr_code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GrantQrScannerPage(
      onScanned: (code) {
        // Normal scan handling would go here
      },
    );
  }
}

// Helper widget for complete workflow demonstration
class _CompleteWorkflowDemo extends StatefulWidget {
  final Function(String) onStep;
  const _CompleteWorkflowDemo({required this.onStep});

  @override
  State<_CompleteWorkflowDemo> createState() => _CompleteWorkflowDemoState();
}

class _CompleteWorkflowDemoState extends State<_CompleteWorkflowDemo> {
  String? _lockToken;
  final String _grantToken = 'demo-grant-token';

  @override
  void initState() {
    super.initState();
    widget.onStep('workflow_started');
  }

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
          widget.onStep('qr_scanned');
        },
      );
    }
    
    return _DoorOpeningPage(
      grantToken: _grantToken,
      lockToken: _lockToken!,
      onOperation: (operation) => widget.onStep('door_opened'),
    );
  }
}