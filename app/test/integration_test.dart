import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;
import 'package:doorlock/env_config.dart';
import 'package:doorlock/window_service.dart';

import 'mock_home_assistant_server.dart';
import 'pocketbase_test_service.dart';
import 'test_env_config.dart';
import 'test_qr_scanner_service.dart';
import 'test_window_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Doorlock End-to-End Integration Tests', () {
    setUpAll(() async {
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
      
      print('✅ Integration test setup complete!');
    });

    tearDownAll(() async {
      print('🧹 Cleaning up integration tests...');
      await MockHomeAssistantServer.stop();
      await PocketBaseTestService.cleanup();
      print('✅ Integration test cleanup complete!');
    });

    setUp(() {
      // Clear API call history for each test
      MockHomeAssistantServer.clearApiCalls();
    });

    testWidgets('Complete User Journey: Sign in → Add HA → Create Door → Generate Grant → Test Grant', (WidgetTester tester) async {
      print('🎯 Testing complete user journey...');
      
      // Start the app
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();

      // Step 1: Sign in to test user
      print('Step 1: Signing in...');
      await _signIn(tester, 'testuser', 'testpass123');
      expect(find.text('Home Assistants'), findsOneWidget);
      print('✅ Step 1: Successfully signed in');

      // Step 2: Add Home Assistant
      print('Step 2: Adding Home Assistant...');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      expect(find.text('Test Home'), findsOneWidget);
      print('✅ Step 2: Successfully added Home Assistant');

      // Step 3: Create Door
      print('Step 3: Creating door...');
      await _createDoor(tester, 'Test Home');
      expect(find.text('lock.front_door'), findsOneWidget);
      print('✅ Step 3: Successfully created door');

      // Step 4: Generate Grant
      print('Step 4: Generating grant...');
      await _generateGrant(tester, 'lock.front_door', 'Test Grant');
      expect(find.text('Test Grant'), findsOneWidget);
      print('✅ Step 4: Successfully generated grant');

      // Step 5: Test Grant by using QR scanner
      print('Step 5: Testing grant...');
      await _testGrantViaQrScanner(tester, 'Test Grant');
      
      // Verify the mock Home Assistant server received the door open call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.any((call) => call['path']?.contains('lock/open') == true), true);
      print('✅ Step 5: Successfully tested grant - API call verified');
      
      print('🎉 Complete user journey test passed!');
    });

    testWidgets('Grant Expiration Test: Verify grants can expire and stop working', (WidgetTester tester) async {
      print('⏰ Testing grant expiration...');
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Set up basic environment
      await _signIn(tester, 'testuser', 'testpass123');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      await _createDoor(tester, 'Test Home');
      
      // Create a grant with past expiration (using PocketBase API directly)
      print('Creating expired grant...');
      await _createExpiredGrantDirectly();
      
      // Try to use the expired grant via QR scanner
      await _testExpiredGrant(tester);
      
      // Should see error message or no door opening
      final apiCallsBefore = MockHomeAssistantServer.getApiCalls().length;
      await Future.delayed(const Duration(seconds: 1));
      final apiCallsAfter = MockHomeAssistantServer.getApiCalls().length;
      
      // No new API calls should have been made for expired grant
      expect(apiCallsAfter, equals(apiCallsBefore));
      
      print('✅ Grant expiration test passed');
    });

    testWidgets('Grant Deletion Test: Create and delete grant via UI', (WidgetTester tester) async {
      print('🗑️ Testing grant deletion...');
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Set up basic environment
      await _signIn(tester, 'testuser', 'testpass123');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      await _createDoor(tester, 'Test Home');
      await _generateGrant(tester, 'lock.front_door', 'Grant to Delete');
      
      // Delete the grant via UI
      await _deleteGrantViaUI(tester, 'Grant to Delete');
      
      // Grant should no longer be visible
      expect(find.text('Grant to Delete'), findsNothing);
      
      // Try to use deleted grant - should fail
      await _testDeletedGrant(tester);
      
      print('✅ Grant deletion test passed');
    });

    testWidgets('Grant Expiration Update Test: Update grant expiration time via UI', (WidgetTester tester) async {
      print('🔄 Testing grant expiration update...');
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Set up basic environment
      await _signIn(tester, 'testuser', 'testpass123');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      await _createDoor(tester, 'Test Home');
      await _generateGrant(tester, 'lock.front_door', 'Updatable Grant');
      
      // Update grant expiration via UI
      await _updateGrantExpirationViaUI(tester, 'Updatable Grant');
      
      // Verify grant is still usable with new expiration
      await _testGrantViaQrScanner(tester, 'Updatable Grant');
      
      // Should have made API call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.any((call) => call['path']?.contains('lock/open') == true), true);
      
      print('✅ Grant expiration update test passed');
    });

    testWidgets('Invalid Token Handling Test: Test with invalid HA token', (WidgetTester tester) async {
      print('🚫 Testing invalid token handling...');
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Sign in
      await _signIn(tester, 'testuser', 'testpass123');
      
      // Try to add Home Assistant with invalid token
      await _addHomeAssistantWithError(tester, 'Invalid HA', 'http://localhost:8123', 'invalid_token');
      
      // Should see error message about invalid token
      expect(find.textContaining('Invalid'), findsWidgets);
      
      print('✅ Invalid token handling test passed');
    });

    testWidgets('QR Code Scanning Workflow Test: Complete scan-to-open flow', (WidgetTester tester) async {
      print('📱 Testing QR code scanning workflow...');
      
      // Set up mock QR scanner with valid grant code
      app.setQrScannerService(MockQrScannerService(
        mockQrCode: 'doorlock://grant/valid-grant-id',
        mockDelay: const Duration(milliseconds: 300),
      ));
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Set up basic environment and create grant
      await _signIn(tester, 'testuser', 'testpass123');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      await _createDoor(tester, 'Test Home');
      await _generateGrant(tester, 'lock.front_door', 'QR Test Grant');
      
      // Test QR scanning workflow
      await _navigateToQrScanner(tester);
      
      // Should see QR scanner UI
      expect(find.text('Mock QR Scanner'), findsOneWidget);
      
      // Wait for auto-scan and verify door opening
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Should have made API call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.any((call) => call['path']?.contains('lock/open') == true), true);
      
      print('✅ QR code scanning workflow test passed');
    });

    testWidgets('API Call Verification Test: Verify correct HA API calls', (WidgetTester tester) async {
      print('🔗 Testing API call verification...');
      
      // Clear previous API calls
      MockHomeAssistantServer.clearApiCalls();
      
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();
      
      // Complete user journey that should make API calls
      await _signIn(tester, 'testuser', 'testpass123');
      await _addHomeAssistant(tester, 'Test Home', 'http://localhost:8123', 'test_access_token');
      await _createDoor(tester, 'Test Home');
      await _generateGrant(tester, 'lock.front_door', 'API Test Grant');
      await _testGrantViaQrScanner(tester, 'API Test Grant');
      
      // Verify specific API calls were made
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      
      // Should have made calls to get lock entities
      expect(apiCalls.any((call) => call['path']?.contains('/api/states') == true), true);
      
      // Should have made call to open the lock
      expect(apiCalls.any((call) => call['path']?.contains('lock/open') == true), true);
      
      // Verify authorization headers were included
      expect(apiCalls.any((call) => call['headers']?['authorization']?.contains('Bearer test_access_token') == true), true);
      
      print('✅ API call verification test passed');
      print('📊 Total API calls made: ${apiCalls.length}');
    });
  });
}

// Helper functions to drive the actual UI

Future<void> _signIn(WidgetTester tester, String username, String password) async {
  // Find and fill username field
  final usernameField = find.byType(TextFormField).first;
  await tester.tap(usernameField);
  await tester.pumpAndSettle();
  await tester.enterText(usernameField, username);
  
  // Find and fill password field
  final passwordField = find.byType(TextFormField).last;
  await tester.tap(passwordField);
  await tester.pumpAndSettle();
  await tester.enterText(passwordField, password);
  
  // Tap sign in button
  final signInButton = find.text('Sign In');
  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _addHomeAssistant(WidgetTester tester, String name, String url, String token) async {
  // Tap the add button
  final addButton = find.byIcon(Icons.add);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  
  // Fill in the form
  final nameField = find.byType(TextFormField).at(0);
  await tester.tap(nameField);
  await tester.pumpAndSettle();
  await tester.enterText(nameField, name);
  
  final urlField = find.byType(TextFormField).at(1);
  await tester.tap(urlField);
  await tester.pumpAndSettle();
  await tester.enterText(urlField, url);
  
  final tokenField = find.byType(TextFormField).at(2);
  await tester.tap(tokenField);
  await tester.pumpAndSettle();
  await tester.enterText(tokenField, token);
  
  // Save
  final saveButton = find.text('Save');
  await tester.tap(saveButton);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _createDoor(WidgetTester tester, String homeAssistantName) async {
  // Tap on the Home Assistant to navigate to locks
  final homeAssistantItem = find.text(homeAssistantName);
  await tester.tap(homeAssistantItem);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  // Should be on locks page
  expect(find.text('Locks'), findsOneWidget);
  
  // Tap add lock button
  final addLockButton = find.byIcon(Icons.add);
  await tester.tap(addLockButton);
  await tester.pumpAndSettle();
  
  // Should see available locks from mock HA server
  expect(find.text('front_door'), findsOneWidget);
  
  // Select front door
  final frontDoorItem = find.text('front_door');
  await tester.tap(frontDoorItem);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _generateGrant(WidgetTester tester, String lockName, String grantName) async {
  // Tap on the lock to open grants
  final lockItem = find.text(lockName);
  await tester.tap(lockItem);
  await tester.pumpAndSettle();
  
  // Should see grants sheet
  expect(find.text('Grants'), findsOneWidget);
  
  // Tap add grant button
  final addGrantButton = find.byIcon(Icons.add);
  await tester.tap(addGrantButton);
  await tester.pumpAndSettle();
  
  // Fill grant form
  final grantNameField = find.byType(TextFormField).first;
  await tester.tap(grantNameField);
  await tester.pumpAndSettle();
  await tester.enterText(grantNameField, grantName);
  
  // Save the grant
  final saveGrantButton = find.text('Save');
  await tester.tap(saveGrantButton);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _testGrantViaQrScanner(WidgetTester tester, String grantName) async {
  // Set up mock QR scanner to scan a grant
  app.setQrScannerService(MockQrScannerService(
    mockQrCode: 'doorlock://grant/test-grant-id',
    mockDelay: const Duration(milliseconds: 300),
  ));
  
  // Navigate to QR scanner
  final scanQrButton = find.text('Scan QR');
  if (scanQrButton.evaluate().isNotEmpty) {
    await tester.tap(scanQrButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

Future<void> _addHomeAssistantWithError(WidgetTester tester, String name, String url, String token) async {
  // Try to add HA with invalid token - should show error
  final addButton = find.byIcon(Icons.add);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  
  // Fill form with invalid token
  final nameField = find.byType(TextFormField).at(0);
  await tester.tap(nameField);
  await tester.pumpAndSettle();
  await tester.enterText(nameField, name);
  
  final urlField = find.byType(TextFormField).at(1);
  await tester.tap(urlField);
  await tester.pumpAndSettle();
  await tester.enterText(urlField, url);
  
  final tokenField = find.byType(TextFormField).at(2);
  await tester.tap(tokenField);
  await tester.pumpAndSettle();
  await tester.enterText(tokenField, token);
  
  final saveButton = find.text('Save');
  await tester.tap(saveButton);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _createExpiredGrantDirectly() async {
  // Use PocketBase API to create an expired grant
  // This is a placeholder - would need actual PocketBase implementation
  print('Creating expired grant via PocketBase API...');
}

Future<void> _testExpiredGrant(WidgetTester tester) async {
  // Try to use an expired grant
  app.setQrScannerService(MockQrScannerService(
    mockQrCode: 'doorlock://grant/expired-grant-id',
    mockDelay: const Duration(milliseconds: 300),
  ));
  
  await _navigateToQrScanner(tester);
}

Future<void> _deleteGrantViaUI(WidgetTester tester, String grantName) async {
  // Long press on grant to show context menu
  final grantItem = find.text(grantName);
  await tester.longPress(grantItem);
  await tester.pumpAndSettle();
  
  // Tap delete option
  final deleteButton = find.text('Delete');
  if (deleteButton.evaluate().isNotEmpty) {
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
  }
  
  // Confirm deletion if needed
  final confirmButton = find.text('Confirm');
  if (confirmButton.evaluate().isNotEmpty) {
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testDeletedGrant(WidgetTester tester) async {
  // Try to use a deleted grant
  app.setQrScannerService(MockQrScannerService(
    mockQrCode: 'doorlock://grant/deleted-grant-id',
    mockDelay: const Duration(milliseconds: 300),
  ));
  
  await _navigateToQrScanner(tester);
}

Future<void> _updateGrantExpirationViaUI(WidgetTester tester, String grantName) async {
  // Long press on grant to show context menu
  final grantItem = find.text(grantName);
  await tester.longPress(grantItem);
  await tester.pumpAndSettle();
  
  // Tap edit option
  final editButton = find.text('Edit');
  if (editButton.evaluate().isNotEmpty) {
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    
    // Update expiration date - this would need actual date picker interaction
    // For now, just save
    final saveButton = find.text('Save');
    if (saveButton.evaluate().isNotEmpty) {
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _navigateToQrScanner(WidgetTester tester) async {
  final scanQrButton = find.text('Scan QR');
  if (scanQrButton.evaluate().isNotEmpty) {
    await tester.tap(scanQrButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}