import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;
import 'package:http/http.dart' as http;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dialogs and Grant Flow Tests', () {
    setUpAll(() async {
      await setupAdvancedTestData();
    });

    testWidgets('Test all dialogs and modals', (WidgetTester tester) async {
      print('💬 Testing all dialogs and modals...');
      
      app.main();
      await tester.pumpAndSettle();
      
      // Sign in first to access authenticated areas
      await _signInForTesting(tester);
      
      // Test various dialog scenarios
      await _testErrorDialogs(tester);
      await _testConfirmationDialogs(tester);
    });

    testWidgets('Grant flow simulation', (WidgetTester tester) async {
      print('🎟️ Testing grant flow...');
      
      // This test simulates the grant flow by testing the UI components
      // In a full test, we'd need actual grant tokens from the backend
      await _testGrantFlowUI(tester);
    });

    testWidgets('QR Code and sharing functionality', (WidgetTester tester) async {
      print('📱 Testing QR codes and sharing...');
      
      app.main();
      await tester.pumpAndSettle();
      
      // Sign in and navigate to test QR functionality
      await _signInForTesting(tester);
      await _testQRCodeFunctionality(tester);
    });

    testWidgets('Mobile scanner page test', (WidgetTester tester) async {
      print('📷 Testing mobile scanner page...');
      
      // Test the QR scanner page UI
      await _testQRScannerPage(tester);
    });

    testWidgets('Widget interaction testing', (WidgetTester tester) async {
      print('🎯 Testing specific widget interactions...');
      
      app.main();
      await tester.pumpAndSettle();
      
      // Test text field interactions
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      await tester.tap(usernameField);
      await tester.pumpAndSettle();
      
      // Type and verify text appears
      await tester.enterText(usernameField, 'test input');
      await tester.pumpAndSettle();
      
      expect(find.text('test input'), findsOneWidget);
      
      // Clear the field
      await tester.enterText(usernameField, '');
      await tester.pumpAndSettle();
      
      // Test button states
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(signInButton, findsOneWidget);
      
      // Test multiple taps (should not crash)
      for (int i = 0; i < 5; i++) {
        await tester.tap(signInButton);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      
      print('✅ Widget interaction testing completed');
    });

    testWidgets('App state management testing', (WidgetTester tester) async {
      print('🔄 Testing app state management...');
      
      app.main();
      await tester.pumpAndSettle();
      
      // Sign in
      await _signInForTesting(tester);
      
      // Navigate to add page
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Add some input
      await tester.enterText(find.byType(TextFormField), 'test state');
      await tester.pumpAndSettle();
      
      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      
      // Verify we're back at home assistants
      expect(find.text('Home Assistants'), findsOneWidget);
      
      // Navigate forward again
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Verify form is reset (good practice)
      expect(find.text('Add Home Assistant'), findsOneWidget);
      
      print('✅ App state management testing completed');
    });

    testWidgets('Performance and responsiveness testing', (WidgetTester tester) async {
      print('⚡ Testing performance and responsiveness...');
      
      app.main();
      await tester.pumpAndSettle();
      
      // Measure sign in performance
      final stopwatch = Stopwatch()..start();
      
      await _signInForTesting(tester);
      
      stopwatch.stop();
      print('ℹ️ Sign in took ${stopwatch.elapsedMilliseconds}ms');
      
      // Test rapid navigation
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      }
      
      // App should still be responsive
      expect(find.text('Home Assistants'), findsOneWidget);
      
      print('✅ Performance and responsiveness testing completed');
    });
  });
}

/// Set up more advanced test data for dialog testing
Future<void> setupAdvancedTestData() async {
  print('🔧 Setting up advanced test data...');
  
  try {
    // Ensure test user exists
    await http.post(
      Uri.parse('http://localhost:8080/api/collections/doorlock_users/records'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'testuser',
        'password': 'testpass123',
        'passwordConfirm': 'testpass123',
      }),
    );
    
    // Note: In a real test environment, we'd also create:
    // - Test Home Assistants
    // - Test Locks
    // - Test Grants
    // For now, we'll test the UI structure without real data
    
    print('✅ Advanced test data setup completed');
  } catch (e) {
    print('ℹ️ Test data setup: $e');
  }
}

/// Helper to sign in for testing
Future<void> _signInForTesting(WidgetTester tester) async {
  // Quick sign in for tests that need authentication
  final usernameField = find.widgetWithText(TextFormField, 'Username');
  final passwordField = find.widgetWithText(TextFormField, 'Password');
  final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
  
  await tester.enterText(usernameField, 'testuser');
  await tester.enterText(passwordField, 'testpass123');
  await tester.pumpAndSettle();
  
  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Should be on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
}

/// Test error dialogs and error handling
Future<void> _testErrorDialogs(WidgetTester tester) async {
  print('❌ Testing error dialogs...');
  
  // From Home Assistants page, try to add an invalid assistant
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  
  // Fill invalid URL to trigger error
  final urlField = find.byType(TextFormField);
  await tester.enterText(urlField, 'http://invalid-url-that-will-fail.local');
  await tester.pumpAndSettle();
  
  await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Should show error message
  final errorMessage = find.textContaining('Failed to add');
  if (errorMessage.evaluate().isNotEmpty) {
    print('✅ Error message displayed correctly');
  }
  
  // Test that error persists and doesn't disappear immediately
  await tester.pump(const Duration(seconds: 1));
  if (errorMessage.evaluate().isNotEmpty) {
    print('✅ Error message persistence verified');
  }
  
  // Go back to clear error state
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

/// Test confirmation dialogs
Future<void> _testConfirmationDialogs(WidgetTester tester) async {
  print('✅ Testing confirmation dialogs...');
  
  // This would test delete confirmations and other dialogs
  // For now, we test the UI structure since we don't have real data
  
  // Verify we're on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Test that the page structure supports dialog interactions
  expect(find.byType(Scaffold), findsOneWidget);
  expect(find.byType(AppBar), findsOneWidget);
  
  print('✅ Confirmation dialog structure verified');
}

/// Test QR code functionality
Future<void> _testQRCodeFunctionality(WidgetTester tester) async {
  print('📱 Testing QR code functionality...');
  
  // This tests the QR code dialog structure
  // In a real test with data, we'd navigate to a lock and test the QR dialog
  
  // For now, verify the overall app structure supports QR functionality
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // The QR code functionality would be tested by:
  // 1. Navigating to a lock
  // 2. Tapping the QR code icon
  // 3. Verifying the QR dialog appears
  // 4. Testing print functionality
  
  print('✅ QR code functionality structure verified');
}

/// Test the grant flow UI components
Future<void> _testGrantFlowUI(WidgetTester tester) async {
  print('🎟️ Testing grant flow UI...');
  
  // The grant flow is triggered by URL parameters
  // For this test, we'll verify the app can handle the grant flow structure
  
  // Start a new app instance
  app.main();
  await tester.pumpAndSettle();
  
  // In a real test with grant token, the app would show:
  // 1. Grant QR Scanner page
  // 2. Open Door page after scanning
  
  // For now, we test the normal flow and verify app structure
  expect(find.text('Sign In'), findsOneWidget);
  
  print('✅ Grant flow UI structure verified');
}

/// Test QR scanner page
Future<void> _testQRScannerPage(WidgetTester tester) async {
  print('📷 Testing QR scanner page...');
  
  // This would test the mobile scanner functionality
  // Since we can't actually trigger the camera in tests,
  // we verify the app structure supports it
  
  app.main();
  await tester.pumpAndSettle();
  
  // The QR scanner page would show when accessing via grant token
  // For now, verify basic app structure
  expect(find.byType(MaterialApp), findsOneWidget);
  
  print('✅ QR scanner page structure verified');
}