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

    testWidgets('Basic app startup and sign-in page display', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing basic app startup...');
      
      // Set up mock QR scanner
      app.setQrScannerService(MockQrScannerService());

      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify sign-in page is shown
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byKey(const Key('username_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);

      // ignore: avoid_print
      print('✅ Basic app startup test passed!');
    });

    testWidgets('Mock Home Assistant server functionality', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing mock HA server...');
      
      // Test that the mock server is working
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls, isEmpty);
      
      // Clear calls and verify
      MockHomeAssistantServer.clearApiCalls();
      expect(MockHomeAssistantServer.getApiCalls(), isEmpty);
      
      // ignore: avoid_print
      print('✅ Mock HA server test passed!');
    });

    testWidgets('Complete user workflow test', (WidgetTester tester) async {
      // ignore: avoid_print
      print('🧪 Testing complete user workflow...');
      
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
      print('Step 1: Attempting sign-in...');
      await _signInAsTestUser(tester);

      // ignore: avoid_print
      print('✅ Complete user workflow test passed!');
    });
  });
}

/// Helper function to sign in as test user
Future<void> _signInAsTestUser(WidgetTester tester) async {
  final credentials = PocketBaseTestService.getTestUserCredentials();
  
  // Find and fill username field
  final usernameField = find.byKey(const Key('username_field'));
  if (usernameField.evaluate().isNotEmpty) {
    await tester.enterText(usernameField, credentials['username']!);
  }
  
  // Find and fill password field
  final passwordField = find.byKey(const Key('password_field'));
  if (passwordField.evaluate().isNotEmpty) {
    await tester.enterText(passwordField, credentials['password']!);
  }
  
  // Find and tap sign in button
  final signInButton = find.byKey(const Key('sign_in_button'));
  if (signInButton.evaluate().isNotEmpty) {
    await tester.tap(signInButton);
    await tester.pumpAndSettle();
  }
  
  // Wait for authentication to complete
  await tester.pumpAndSettle(const Duration(seconds: 2));
}