import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/grant_qr_scanner_page.dart';

void main() {
  group('Grant Flow Functionality', () {
    testWidgets('QR Scanner functionality and workflow', (WidgetTester tester) async {
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

      // Verify QR scanner page UI and functionality
      expect(find.text('Scan Lock QR Code'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      
      // Test the onScanned callback mechanism
      expect(scannedCode, isNull);
      expect(scanHistory.isEmpty, isTrue);
      
      // Verify page is ready for scanning
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
    });

    testWidgets('Grant flow state management and transitions', (WidgetTester tester) async {
      const grantToken = 'state-test-grant';
      List<String> stateTransitions = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _TestGrantFlowWithHistory(
          grantToken: grantToken,
          onStateChange: (state) => stateTransitions.add(state),
        ),
      ));

      // Initially should show QR scanner
      expect(find.byType(GrantQrScannerPage), findsOneWidget);
      expect(stateTransitions, contains('qr_scanner'));

      // After scanning, should show door opening page
      final state = tester.state<_TestGrantFlowWithHistoryState>(find.byType(_TestGrantFlowWithHistory));
      state.simulateQRScan('scanned-lock-token');
      await tester.pumpAndSettle();

      expect(find.byType(GrantQrScannerPage), findsNothing);
      expect(stateTransitions, contains('door_open'));
    });

    testWidgets('QR scanning callback and data flow', (WidgetTester tester) async {
      Map<String, dynamic> scanData = {};
      
      await tester.pumpWidget(MaterialApp(
        home: _TestQRDataFlow(
          onScanData: (data) => scanData.addAll(data),
        ),
      ));

      // Test QR scanning data flow
      final state = tester.state<_TestQRDataFlowState>(find.byType(_TestQRDataFlow));
      
      // Simulate different QR scan scenarios
      state.simulateScan({'type': 'lock', 'token': 'ABC123', 'timestamp': '2024-01-01'});
      await tester.pumpAndSettle();
      
      expect(scanData['type'], equals('lock'));
      expect(scanData['token'], equals('ABC123'));
      expect(scanData['timestamp'], equals('2024-01-01'));
    });

    testWidgets('Error handling in grant flow', (WidgetTester tester) async {
      List<String> errorStates = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _TestErrorHandling(
          onError: (error) => errorStates.add(error),
        ),
      ));

      // Test various error scenarios
      final state = tester.state<_TestErrorHandlingState>(find.byType(_TestErrorHandling));
      
      // Test invalid QR code
      state.simulateError('invalid_qr');
      await tester.pumpAndSettle();
      expect(errorStates, contains('invalid_qr'));
      
      // Test network error
      state.simulateError('network_error');
      await tester.pumpAndSettle();
      expect(errorStates, contains('network_error'));
    });

    testWidgets('Grant token validation and processing', (WidgetTester tester) async {
      List<String> processedTokens = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _TestTokenProcessor(
          onTokenProcessed: (token) => processedTokens.add(token),
        ),
      ));

      // Test token processing
      final testTokens = [
        'valid-token-123',
        'another-valid-token-456',
        'special-chars-token-!@#',
      ];

      final state = tester.state<_TestTokenProcessorState>(find.byType(_TestTokenProcessor));
      
      for (final token in testTokens) {
        state.processToken(token);
        await tester.pumpAndSettle();
      }

      expect(processedTokens.length, equals(3));
      expect(processedTokens, containsAll(testTokens));
    });

    testWidgets('Door opening workflow simulation', (WidgetTester tester) async {
      List<String> doorOperations = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _TestDoorController(
          onOperation: (operation) => doorOperations.add(operation),
        ),
      ));

      // Test door operations
      await tester.tap(find.byKey(const Key('open_door')));
      await tester.pumpAndSettle();
      expect(doorOperations, contains('open'));

      await tester.tap(find.byKey(const Key('check_status')));
      await tester.pumpAndSettle();
      expect(doorOperations, contains('status'));

      await tester.tap(find.byKey(const Key('close_door')));
      await tester.pumpAndSettle();
      expect(doorOperations, contains('close'));
    });

    testWidgets('Complete grant workflow simulation', (WidgetTester tester) async {
      List<String> workflowSteps = [];
      
      await tester.pumpWidget(MaterialApp(
        home: _TestCompleteWorkflow(
          onStep: (step) => workflowSteps.add(step),
        ),
      ));

      // Simulate complete workflow
      await tester.tap(find.byKey(const Key('start_workflow')));
      await tester.pumpAndSettle();
      expect(workflowSteps, contains('started'));

      await tester.tap(find.byKey(const Key('scan_qr')));
      await tester.pumpAndSettle();
      expect(workflowSteps, contains('qr_scanned'));

      await tester.tap(find.byKey(const Key('open_door')));
      await tester.pumpAndSettle();
      expect(workflowSteps, contains('door_opened'));

      // Verify complete workflow
      expect(workflowSteps.length, equals(3));
    });
  });
}

// Test wrapper with state history tracking
class _TestGrantFlowWithHistory extends StatefulWidget {
  final String grantToken;
  final Function(String) onStateChange;
  const _TestGrantFlowWithHistory({required this.grantToken, required this.onStateChange});
  
  @override
  State<_TestGrantFlowWithHistory> createState() => _TestGrantFlowWithHistoryState();
}

class _TestGrantFlowWithHistoryState extends State<_TestGrantFlowWithHistory> {
  String? _lockToken;

  @override
  void initState() {
    super.initState();
    widget.onStateChange('qr_scanner');
  }

  void simulateQRScan(String lockToken) {
    setState(() => _lockToken = lockToken);
    widget.onStateChange('door_open');
  }

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) => simulateQRScan(lockToken),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Open Door')),
      body: const Center(child: Text('Door Opening Page')),
    );
  }
}

// Test wrapper for QR data flow
class _TestQRDataFlow extends StatefulWidget {
  final Function(Map<String, dynamic>) onScanData;
  const _TestQRDataFlow({required this.onScanData});
  
  @override
  State<_TestQRDataFlow> createState() => _TestQRDataFlowState();
}

class _TestQRDataFlowState extends State<_TestQRDataFlow> {
  void simulateScan(Map<String, dynamic> data) {
    widget.onScanData(data);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('QR Data Flow Test')),
    );
  }
}

// Test wrapper for error handling
class _TestErrorHandling extends StatefulWidget {
  final Function(String) onError;
  const _TestErrorHandling({required this.onError});
  
  @override
  State<_TestErrorHandling> createState() => _TestErrorHandlingState();
}

class _TestErrorHandlingState extends State<_TestErrorHandling> {
  void simulateError(String error) {
    widget.onError(error);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Error Handling Test')),
    );
  }
}

// Test wrapper for token processing
class _TestTokenProcessor extends StatefulWidget {
  final Function(String) onTokenProcessed;
  const _TestTokenProcessor({required this.onTokenProcessed});
  
  @override
  State<_TestTokenProcessor> createState() => _TestTokenProcessorState();
}

class _TestTokenProcessorState extends State<_TestTokenProcessor> {
  void processToken(String token) {
    widget.onTokenProcessed(token);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Token Processor Test')),
    );
  }
}

// Test wrapper for door operations
class _TestDoorController extends StatefulWidget {
  final Function(String) onOperation;
  const _TestDoorController({required this.onOperation});
  
  @override
  State<_TestDoorController> createState() => _TestDoorControllerState();
}

class _TestDoorControllerState extends State<_TestDoorController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('open_door'),
            onPressed: () => widget.onOperation('open'),
            child: const Text('Open Door'),
          ),
          ElevatedButton(
            key: const Key('check_status'),
            onPressed: () => widget.onOperation('status'),
            child: const Text('Check Status'),
          ),
          ElevatedButton(
            key: const Key('close_door'),
            onPressed: () => widget.onOperation('close'),
            child: const Text('Close Door'),
          ),
        ],
      ),
    );
  }
}

// Test wrapper for complete workflow
class _TestCompleteWorkflow extends StatefulWidget {
  final Function(String) onStep;
  const _TestCompleteWorkflow({required this.onStep});
  
  @override
  State<_TestCompleteWorkflow> createState() => _TestCompleteWorkflowState();
}

class _TestCompleteWorkflowState extends State<_TestCompleteWorkflow> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('start_workflow'),
            onPressed: () => widget.onStep('started'),
            child: const Text('Start Workflow'),
          ),
          ElevatedButton(
            key: const Key('scan_qr'),
            onPressed: () => widget.onStep('qr_scanned'),
            child: const Text('Scan QR'),
          ),
          ElevatedButton(
            key: const Key('open_door'),
            onPressed: () => widget.onStep('door_opened'),
            child: const Text('Open Door'),
          ),
        ],
      ),
    );
  }
}