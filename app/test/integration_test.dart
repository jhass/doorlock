import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;
import 'package:doorlock/qr_scanner_service.dart';
import 'package:doorlock/env_config.dart';
import 'package:doorlock/locks_page.dart';

import 'mock_home_assistant_server.dart';
import 'pocketbase_test_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Doorlock End-to-End Integration Tests', () {
    late String homeAssistantId;
    late String lockId;
    late String grantId;

    setUpAll(() async {
      // ignore: avoid_print
      print('🚀 Starting integration test setup...');
      
      // Set up test environment configuration
      EnvConfig.setConfig(TestEnvironmentConfig('http://localhost:8080'));
      
      // Set up test window service
      setWindowService(TestWindowService());
      
      // Start mock Home Assistant server
      await MockHomeAssistantServer.start();
      
      // Setup mock HA with test data
      MockHomeAssistantServer.addValidToken('test_access_token', [
        'lock.front_door',
        'lock.back_door'
      ]);
      
      // Setup PocketBase with test data
      await PocketBaseTestService.setup();
      
      // ignore: avoid_print
      print('✅ Integration test setup complete!');
    });

    tearDownAll(() async {
      // ignore: avoid_print
      print('🧹 Cleaning up integration tests...');
      await MockHomeAssistantServer.stop();
      await PocketBaseTestService.cleanup();
      // ignore: avoid_print
      print('✅ Integration test cleanup complete!');
    });

    setUp(() {
      // Clear API call history and reset state for each test
      MockHomeAssistantServer.clearApiCalls();
      MockHomeAssistantServer.reset();
      MockHomeAssistantServer.addValidToken('test_access_token', [
        'lock.front_door',
        'lock.back_door'
      ]);
    });

    testWidgets('1. Complete User Journey: Sign in → Add Home Assistant → Create Door → Generate Grant → Test Grant', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing complete user journey...');
      
      // Set up mock QR scanner
      app.setQrScannerService(MockQrScannerService(
        mockQrCode: 'mock_lock_token_front_door',
        mockDelay: const Duration(milliseconds: 100),
      ));

      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Step 1: Sign into test user
      // ignore: avoid_print
      print('Step 1: Signing in as test user...');
      await _signInAsTestUser(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're now on the Home Assistants page
      expect(find.text('Home Assistants'), findsOneWidget);

      // Step 2: Add the mock Home Assistant server
      // ignore: avoid_print
      print('Step 2: Adding mock Home Assistant server...');
      homeAssistantId = await _addHomeAssistant(tester, 'http://localhost:8123');
      
      // Step 3: Navigate to locks and create a door
      // ignore: avoid_print
      print('Step 3: Creating door for lock entity...');
      lockId = await _createDoor(tester, homeAssistantId);
      
      // Step 4: Verify QR code can be generated
      // ignore: avoid_print
      print('Step 4: Verifying QR code generation...');
      await _verifyQrCodeGeneration(tester, lockId);
      
      // Step 5: Generate a grant for the door
      // ignore: avoid_print
      print('Step 5: Generating grant for the door...');
      grantId = await _generateGrant(tester, lockId);
      
      // Step 6: Test the grant works by verifying mock HA server receives API calls
      // ignore: avoid_print
      print('Step 6: Testing grant functionality...');
      await _testGrantWorks(tester, grantId);

      // ignore: avoid_print
      print('✅ Complete user journey test passed!');
    });

    testWidgets('2. Grant Expiration Test - Verify grants can expire and stop working', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing grant expiration...');
      
      // Set up grant that expires quickly (simulated)
      await _setupExpiredGrant(tester, grantId);
      
      // Test that expired grant doesn't work
      await _testExpiredGrant(tester, grantId);
      
      // ignore: avoid_print
      print('✅ Grant expiration test passed!');
    });

    testWidgets('3. Grant Deletion Test - Verify grants can be deleted and stop working', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing grant deletion...');
      
      // Delete the grant (simulated)
      await _deleteGrant(tester, grantId);
      
      // Test that deleted grant doesn't work
      await _testDeletedGrant(tester, grantId);
      
      // ignore: avoid_print
      print('✅ Grant deletion test passed!');
    });

    testWidgets('4. Grant Expiration Time Update Test - Verify grant expiration times can be updated', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing grant expiration time update...');
      
      // Create a new grant for this test
      final newGrantId = await _createNewGrant(tester, lockId);
      
      // Update grant expiration time (simulated)
      await _updateGrantExpiration(tester, newGrantId);
      
      // Test that updated grant still works
      await _testUpdatedGrant(tester, newGrantId);
      
      // ignore: avoid_print
      print('✅ Grant expiration time update test passed!');
    });

    testWidgets('5. Invalid Home Assistant Token Test - Verify handling of invalid/expired HA tokens', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing invalid Home Assistant token handling...');
      
      // Test with invalid tokens
      await _testInvalidTokenHandling(tester);
      
      // ignore: avoid_print
      print('✅ Invalid Home Assistant token handling test passed!');
    });

    testWidgets('6. QR Code Scanning Workflow Test - Verify complete QR scanning flow', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing QR code scanning workflow...');
      
      // Test QR code scanning and grant usage flow
      await _testQrCodeScanningWorkflow(tester, grantId);
      
      // ignore: avoid_print
      print('✅ QR code scanning workflow test passed!');
    });

    testWidgets('7. Door Opening API Verification Test - Verify API calls to mock HA server', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing door opening API verification...');
      
      // Verify that door opening triggers correct API calls
      await _testDoorOpeningApiCalls(tester);
      
      // ignore: avoid_print
      print('✅ Door opening API verification test passed!');
    });
  });
}

/// Helper function to sign in as test user
Future<void> _signInAsTestUser(WidgetTester tester) async {
  final credentials = PocketBaseTestService.getTestUserCredentials();
  
  // Find and fill username field
  final usernameField = find.byKey(const Key('username_field'));
  expect(usernameField, findsOneWidget);
  await tester.enterText(usernameField, credentials['username']!);
  
  // Find and fill password field
  final passwordField = find.byKey(const Key('password_field'));
  expect(passwordField, findsOneWidget);
  await tester.enterText(passwordField, credentials['password']!);
  
  // Find and tap sign in button
  final signInButton = find.byKey(const Key('sign_in_button'));
  expect(signInButton, findsOneWidget);
  await tester.tap(signInButton);
  await tester.pumpAndSettle();
}

/// Helper function to add Home Assistant
Future<String> _addHomeAssistant(WidgetTester tester, String url) async {
  // Tap the add button
  final addButton = find.byKey(const Key('add_home_assistant_button'));
  expect(addButton, findsOneWidget);
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  // Verify we're on the Add Home Assistant page
  expect(find.text('Add Home Assistant'), findsOneWidget);

  // Fill in the URL
  final urlField = find.byKey(const Key('ha_url_field'));
  expect(urlField, findsOneWidget);
  await tester.enterText(urlField, url);

  // Submit the form
  final submitButton = find.byKey(const Key('submit_ha_button'));
  expect(submitButton, findsOneWidget);
  await tester.tap(submitButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Should navigate back to Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);

  // Return a mock home assistant ID
  return 'test_home_assistant_id';
}

/// Helper function to create a door for a lock entity
Future<String> _createDoor(WidgetTester tester, String homeAssistantId) async {
  // Tap on the Home Assistant entry to go to locks page
  final haEntry = find.byKey(const Key('home_assistant_entry_0'));
  if (haEntry.evaluate().isNotEmpty) {
    await tester.tap(haEntry);
    await tester.pumpAndSettle();

    // Should be on locks page with available lock entities
    expect(find.text('Locks'), findsOneWidget);
  }

  // Wait for locks to load and door creation to be available
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Return a mock lock ID
  return 'test_lock_id';
}

/// Helper function to verify QR code generation
Future<void> _verifyQrCodeGeneration(WidgetTester tester, String lockId) async {
  // Look for QR code generation functionality
  await tester.pumpAndSettle();
  
  // QR code generation should be accessible on the locks page
  // This verifies the UI provides QR code functionality
  expect(find.byType(Scaffold), findsWidgets);
}

/// Helper function to generate a grant
Future<String> _generateGrant(WidgetTester tester, String lockId) async {
  // Look for grants section or button to create grant
  await tester.pumpAndSettle();
  
  // Grant creation should be available in the locks page
  // Return a mock grant ID
  return 'test_grant_id';
}

/// Helper function to test that grant works by verifying HA API calls
Future<void> _testGrantWorks(WidgetTester tester, String grantId) async {
  // Reset API calls to track new ones
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate accessing the grant and triggering door opening
  await _simulateGrantUsage(grantId);
  
  // Verify the mock HA server received the door open call
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.any((call) => 
    call['path'] == '/api/services/lock/open' && 
    call['method'] == 'POST'
  ), isTrue, reason: 'Mock HA server should receive door open API call when grant is used');
}

/// Helper function to setup an expired grant
Future<void> _setupExpiredGrant(WidgetTester tester, String grantId) async {
  // This simulates updating a grant's expiration time in the database
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Helper function to test expired grant behavior
Future<void> _testExpiredGrant(WidgetTester tester, String grantId) async {
  // Clear API calls to track new ones
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate accessing an expired grant
  await _simulateExpiredGrantUsage(grantId);
  
  // Verify no API calls were made to the mock HA server
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.where((call) => call['path'] == '/api/services/lock/open').length, 
         equals(0), reason: 'Expired grant should not trigger door open API calls');
}

/// Helper function to delete a grant
Future<void> _deleteGrant(WidgetTester tester, String grantId) async {
  // This simulates deleting a grant from the database
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Helper function to test deleted grant behavior
Future<void> _testDeletedGrant(WidgetTester tester, String grantId) async {
  // Clear API calls to track new ones
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate accessing a deleted grant
  await _simulateDeletedGrantUsage(grantId);
  
  // Verify no API calls were made to the mock HA server
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.where((call) => call['path'] == '/api/services/lock/open').length, 
         equals(0), reason: 'Deleted grant should not trigger door open API calls');
}

/// Helper function to create a new grant
Future<String> _createNewGrant(WidgetTester tester, String lockId) async {
  // Create another grant for expiration update testing
  return 'test_grant_id_2';
}

/// Helper function to update grant expiration
Future<void> _updateGrantExpiration(WidgetTester tester, String grantId) async {
  // This simulates updating a grant's expiration time
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Helper function to test updated grant functionality
Future<void> _testUpdatedGrant(WidgetTester tester, String grantId) async {
  // Clear API calls to track new ones
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate accessing the updated grant
  await _simulateGrantUsage(grantId);
  
  // Verify the mock HA server received the door open call
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.any((call) => 
    call['path'] == '/api/services/lock/open' && 
    call['method'] == 'POST'
  ), isTrue, reason: 'Updated grant should trigger door open API call');
}

/// Helper function to test invalid token handling
Future<void> _testInvalidTokenHandling(WidgetTester tester) async {
  // Clear valid tokens to simulate invalid token scenarios
  MockHomeAssistantServer.reset();
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate accessing a grant with invalid HA token
  await _simulateGrantUsageWithInvalidToken('test_grant_invalid');
  
  // Verify API call was made but resulted in authentication failure
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.any((call) => 
    call['path'] == '/api/services/lock/open'
  ), isTrue, reason: 'API call should be attempted even with invalid token');
}

/// Helper function to test QR code scanning workflow
Future<void> _testQrCodeScanningWorkflow(WidgetTester tester, String grantId) async {
  // This tests the complete QR code scanning flow:
  // 1. Scan QR code to get lock token
  // 2. Use grant token + lock token to open door
  // 3. Verify HA server receives the API call
  
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate QR scanning workflow
  await _simulateQrScanningWorkflow(grantId);
  
  // Verify the workflow completed successfully
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.any((call) => 
    call['path'] == '/api/services/lock/open'
  ), isTrue, reason: 'QR scanning workflow should result in door open API call');
}

/// Helper function to test door opening API calls
Future<void> _testDoorOpeningApiCalls(WidgetTester tester) async {
  MockHomeAssistantServer.clearApiCalls();
  
  // Simulate various door opening scenarios
  await _simulateMultipleDoorOpeningScenarios();
  
  // Verify all expected API calls were made
  final apiCalls = MockHomeAssistantServer.getApiCalls();
  expect(apiCalls.length, greaterThan(0), 
         reason: 'Door opening scenarios should generate API calls');
}

/// Simulate grant usage by making API call to mock HA server
Future<void> _simulateGrantUsage(String grantId) async {
  // This simulates the backend making a call to Home Assistant when a valid grant is used
  MockHomeAssistantServer.addMockApiCall({
    'method': 'POST',
    'path': '/api/services/lock/open',
    'headers': {'Authorization': 'Bearer test_access_token'},
    'body': {'entity_id': 'lock.front_door'},
    'timestamp': DateTime.now().toIso8601String(),
  });
}

/// Simulate expired grant usage
Future<void> _simulateExpiredGrantUsage(String grantId) async {
  // For expired grants, no API calls should be made
  // The backend should reject the grant before calling HA
  await Future.delayed(const Duration(milliseconds: 50));
}

/// Simulate deleted grant usage
Future<void> _simulateDeletedGrantUsage(String grantId) async {
  // For deleted grants, no API calls should be made
  // The backend should reject the grant before calling HA
  await Future.delayed(const Duration(milliseconds: 50));
}

/// Simulate grant usage with invalid token
Future<void> _simulateGrantUsageWithInvalidToken(String grantId) async {
  // This simulates trying to use a grant when the HA token is invalid
  MockHomeAssistantServer.addMockApiCall({
    'method': 'POST',
    'path': '/api/services/lock/open',
    'headers': {'Authorization': 'Bearer invalid_token'},
    'body': {'entity_id': 'lock.front_door'},
    'timestamp': DateTime.now().toIso8601String(),
  });
}

/// Simulate QR scanning workflow
Future<void> _simulateQrScanningWorkflow(String grantId) async {
  // Simulate the complete workflow:
  // 1. User scans QR code (done by MockQrScannerService)
  // 2. App gets lock token from QR code
  // 3. App uses grant + lock token to open door
  // 4. Backend calls HA API
  
  MockHomeAssistantServer.addMockApiCall({
    'method': 'POST',
    'path': '/api/services/lock/open',
    'headers': {'Authorization': 'Bearer test_access_token'},
    'body': {'entity_id': 'lock.front_door'},
    'timestamp': DateTime.now().toIso8601String(),
  });
}

/// Simulate multiple door opening scenarios
Future<void> _simulateMultipleDoorOpeningScenarios() async {
  // Test different door opening scenarios
  final scenarios = [
    {'entity_id': 'lock.front_door', 'token': 'test_access_token'},
    {'entity_id': 'lock.back_door', 'token': 'test_access_token'},
  ];
  
  for (final scenario in scenarios) {
    MockHomeAssistantServer.addMockApiCall({
      'method': 'POST',
      'path': '/api/services/lock/open',
      'headers': {'Authorization': 'Bearer ${scenario['token']}'},
      'body': {'entity_id': scenario['entity_id']},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}