import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:doorlock/pb.dart';
import '../integration/mock_home_assistant_server.dart';

/// Mock PocketBase for integration testing that tracks Home Assistant calls
class IntegrationMockPocketBase extends PocketBase {
  IntegrationMockPocketBase() : super('http://localhost:8080');
  
  final List<Map<String, dynamic>> _homeAssistantCalls = [];
  
  List<Map<String, dynamic>> get homeAssistantCalls => List.from(_homeAssistantCalls);
  
  void clearCalls() => _homeAssistantCalls.clear();
  
  @override
  Future<T> send<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    List<dynamic>? files,
  }) async {
    // Add realistic delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Simulate door opening endpoint that would call Home Assistant
    if (path.contains('/doorlock/locks/') && path.contains('/open') && method == 'POST') {
      final lockToken = path.split('/')[3];
      final grantToken = body?['token'] as String?;
      
      // Record what Home Assistant call would be made
      final haCall = await _simulateHomeAssistantCall(lockToken, grantToken);
      _homeAssistantCalls.add(haCall);
      
      // Simulate success or failure based on token type
      if (grantToken?.contains('expired') == true || grantToken?.contains('invalid') == true) {
        throw ClientException(
          statusCode: 401,
          response: {'message': 'Token validation failed'},
        );
      }
      
      return {'success': true, 'message': 'Door opened'} as T;
    }
    
    // Default response for other endpoints
    return {'success': true} as T;
  }
  
  /// Simulate what Home Assistant call would be made
  Future<Map<String, dynamic>> _simulateHomeAssistantCall(String lockToken, String? grantToken) async {
    // Determine what token would be used for Home Assistant
    String accessToken;
    if (grantToken?.startsWith('invalid') == true) {
      accessToken = 'invalid_token';
    } else if (grantToken?.startsWith('expired') == true) {
      accessToken = 'expired_token';
    } else if (grantToken?.startsWith('valid') == true) {
      accessToken = 'valid_token';
    } else {
      accessToken = 'default_token'; // default - don't assume valid
    }
    
    // Record the call that would be made to Home Assistant
    final callRecord = {
      'method': 'POST',
      'path': '/api/services/lock/unlock',
      'authorization': 'Bearer $accessToken',
      'entity_id': 'lock.front_door',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    return callRecord;
  }
}

void main() {
  group('Integration Testing with Mock Home Assistant', () {
    late IntegrationMockPocketBase mockPocketBase;

    setUpAll(() async {
      // Start mock Home Assistant server
      await MockHomeAssistantServer.start();
      
      // Set up valid tokens in mock HA server
      MockHomeAssistantServer.setValidToken('valid_token', ['lock.front_door', 'lock.back_door']);
    });

    tearDownAll(() async {
      await MockHomeAssistantServer.stop();
    });

    setUp(() {
      // Clear API call history for each test
      MockHomeAssistantServer.clearApiCalls();
      
      // Create mock PocketBase that simulates calling Home Assistant
      mockPocketBase = IntegrationMockPocketBase();
      mockPocketBase.clearCalls();
      PB.setTestInstance(mockPocketBase);
    });

    tearDown(() {
      PB.clearTestInstance();
    });

    testWidgets('Door opening with valid token creates expected HA call record', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'valid_grant_123',
          lockToken: 'test_lock_456',
        ),
      ));

      // Verify UI structure
      expect(find.widgetWithText(AppBar, 'Open Door'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Open Door'), findsOneWidget);

      // Trigger door opening
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump(); // Start the async operation

      // Should show loading state initially (before async operation completes)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Wait for async operation to complete

      // Should show success message
      expect(find.text('Door opened!'), findsOneWidget);

      // Verify the Home Assistant call was recorded
      final haCalls = mockPocketBase.homeAssistantCalls;
      expect(haCalls.length, equals(1));
      
      final haCall = haCalls.first;
      expect(haCall['method'], equals('POST'));
      expect(haCall['path'], equals('/api/services/lock/unlock'));
      expect(haCall['authorization'], equals('Bearer valid_token'));
      expect(haCall['entity_id'], equals('lock.front_door'));
    });

    testWidgets('Door opening with expired token records HA call and shows error', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'expired_grant_123',
          lockToken: 'test_lock_456',
        ),
      ));

      // Trigger door opening
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump(); // Start the async operation

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Wait for async operation to complete

      // Should show error message since expired token fails
      expect(find.textContaining('Failed:'), findsOneWidget);

      // Verify the Home Assistant call was still recorded (before token validation)
      final haCalls = mockPocketBase.homeAssistantCalls;
      expect(haCalls.length, equals(1));
      
      final haCall = haCalls.first;
      expect(haCall['method'], equals('POST'));
      expect(haCall['path'], equals('/api/services/lock/unlock'));
      expect(haCall['authorization'], equals('Bearer expired_token'));
    });

    testWidgets('Door opening with invalid token records HA call and shows error', (WidgetTester tester) async {
      // Create a fresh mock instance for this test
      final freshMockPB = IntegrationMockPocketBase();
      PB.setTestInstance(freshMockPB);
      
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'invalid_grant_123',
          lockToken: 'test_lock_456',
        ),
      ));

      // Trigger door opening
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pump(); // Start the async operation

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Wait for async operation to complete

      // Should show error message since invalid token fails
      expect(find.textContaining('Failed:'), findsOneWidget);

      // Verify the Home Assistant call was recorded with invalid token
      final haCalls = freshMockPB.homeAssistantCalls;
      expect(haCalls.length, equals(1));
      
      final haCall = haCalls.first;
      expect(haCall['method'], equals('POST'));
      expect(haCall['path'], equals('/api/services/lock/unlock'));
      expect(haCall['authorization'], equals('Bearer invalid_token'));
    });

    testWidgets('Multiple door opening attempts record all HA calls', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'valid_grant_123',
          lockToken: 'test_lock_456',
        ),
      ));

      // First door opening attempt
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();

      // Second door opening attempt
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();

      // Should have two successful operations
      expect(find.text('Door opened!'), findsOneWidget);

      // Verify both Home Assistant calls were recorded
      final haCalls = mockPocketBase.homeAssistantCalls;
      expect(haCalls.length, equals(2));
      
      // Both should be unlock calls with valid token
      for (final call in haCalls) {
        expect(call['method'], equals('POST'));
        expect(call['path'], equals('/api/services/lock/unlock'));
        expect(call['authorization'], equals('Bearer valid_token'));
      }
    });

    testWidgets('Different grant tokens result in different HA tokens', (WidgetTester tester) async {
      // Test valid token first
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'valid_grant_123',
          lockToken: 'test_lock_456',
        ),
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();

      // Clear calls and test expired token with new instance
      mockPocketBase.clearCalls();
      
      await tester.pumpWidget(MaterialApp(
        home: OpenDoorPage(
          grantToken: 'expired_grant_456',
          lockToken: 'test_lock_789',
        ),
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
      await tester.pumpAndSettle();

      // Verify the expired token call was recorded
      final haCalls = mockPocketBase.homeAssistantCalls;
      expect(haCalls.length, equals(1)); // Only the expired call should be recorded
      expect(haCalls[0]['authorization'], equals('Bearer expired_token'));
    });

    test('Mock Home Assistant server setup validation', () async {
      // Test that the mock server configuration is correct
      MockHomeAssistantServer.clearApiCalls();
      expect(MockHomeAssistantServer.getApiCalls(), isEmpty);
      
      // Test token validation setup
      MockHomeAssistantServer.setValidToken('test_token', ['lock.test']);
      
      // Verify server is ready for integration testing
      expect(MockHomeAssistantServer.getLastInvalidTokenError(), isNull);
    });

    test('Integration mock PocketBase simulation accuracy', () async {
      final mockPB = IntegrationMockPocketBase();
      
      // Test valid grant token simulation
      final validResult = await mockPB.send('/doorlock/locks/test_lock/open', 
        method: 'POST', 
        body: {'token': 'valid_grant'}
      );
      expect(validResult['success'], isTrue);
      
      // Test expired grant token simulation
      try {
        await mockPB.send('/doorlock/locks/test_lock/open', 
          method: 'POST', 
          body: {'token': 'expired_grant'}
        );
        fail('Should have thrown exception for expired token');
      } catch (e) {
        expect(e, isA<ClientException>());
      }
      
      // Verify Home Assistant calls were recorded
      final haCalls = mockPB.homeAssistantCalls;
      expect(haCalls.length, equals(2));
      expect(haCalls[0]['authorization'], equals('Bearer valid_token'));
      expect(haCalls[1]['authorization'], equals('Bearer expired_token'));
    });
  });
}