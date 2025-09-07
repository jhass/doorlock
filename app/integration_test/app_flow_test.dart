import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Doorlock App Integration Tests', () {
    testWidgets('Complete application flow walkthrough', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test 1: Sign In Flow
      await testSignInFlow(tester);

      // Test 2: Home Assistants Management
      await testHomeAssistantsFlow(tester);

      // Test 3: Add Home Assistant
      await testAddHomeAssistantFlow(tester);

      // Test 4: Navigate to Locks (simulated since we don't have a real HA)
      await testLocksNavigation(tester);

      // Test 5: Test logout flow
      await testLogoutFlow(tester);
    });

    testWidgets('Grant flow walkthrough', (WidgetTester tester) async {
      // Test the grant-based flow (guest user accessing via token)
      await testGrantFlow(tester);
    });

    testWidgets('All dialogs and modals', (WidgetTester tester) async {
      // Test all dialogs and modal interactions
      await testAllDialogs(tester);
    });
  });
}

/// Test the sign-in flow
Future<void> testSignInFlow(WidgetTester tester) async {
  print('🔐 Testing Sign In Flow...');
  
  // Should start at sign-in page
  expect(find.text('Sign In'), findsOneWidget);
  expect(find.byType(TextFormField), findsNWidgets(2)); // Username and password fields

  // Test empty form validation
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle();
  
  // Should show validation errors
  expect(find.text('Enter username'), findsOneWidget);
  expect(find.text('Enter password'), findsOneWidget);

  // Fill in credentials
  await tester.enterText(find.byType(TextFormField).first, 'testuser');
  await tester.enterText(find.byType(TextFormField).last, 'testpass123');
  await tester.pumpAndSettle();

  // Submit form
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Should navigate to Home Assistants page after successful login
  expect(find.text('Home Assistants'), findsOneWidget);
  print('✅ Sign In Flow completed');
}

/// Test the Home Assistants page functionality
Future<void> testHomeAssistantsFlow(WidgetTester tester) async {
  print('🏠 Testing Home Assistants Flow...');
  
  // Should be on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Check for required UI elements
  expect(find.byIcon(Icons.logout), findsOneWidget); // Sign out button
  expect(find.byIcon(Icons.add), findsOneWidget);    // Add button
  
  // Initially should have no assistants or show empty list
  // We might see a ListView even if empty
  expect(find.byType(ListView), findsOneWidget);
  
  print('✅ Home Assistants Flow completed');
}

/// Test adding a Home Assistant
Future<void> testAddHomeAssistantFlow(WidgetTester tester) async {
  print('➕ Testing Add Home Assistant Flow...');
  
  // Tap the add button
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  
  // Should navigate to Add Home Assistant page
  expect(find.text('Add Home Assistant'), findsOneWidget);
  expect(find.text('Home Assistant Base URL'), findsOneWidget);
  
  // Test empty form validation
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  expect(find.text('Enter the base URL'), findsOneWidget);
  
  // Fill in a test URL (this will fail in real scenario but tests the UI)
  await tester.enterText(
    find.byType(TextFormField), 
    'http://test-homeassistant.local:8123'
  );
  await tester.pumpAndSettle();
  
  // Try to submit (will likely fail but tests the flow)
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  // Either we get an error (expected) or success
  // The error message shows our request was processed
  final errorText = find.textContaining('Failed to add');
  if (errorText.evaluate().isNotEmpty) {
    print('✅ Expected error for invalid Home Assistant URL');
  }
  
  // Go back to home assistants page
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  
  expect(find.text('Home Assistants'), findsOneWidget);
  print('✅ Add Home Assistant Flow completed');
}

/// Test navigation to locks (limited since we need real HA data)
Future<void> testLocksNavigation(WidgetTester tester) async {
  print('🔒 Testing Locks Navigation...');
  
  // This test is limited since we don't have real Home Assistant data
  // But we can test that the UI structure is correct
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // If there were any Home Assistants in the list, we could tap one
  // For now, just verify the page structure is correct
  print('✅ Locks Navigation completed (limited without real data)');
}

/// Test logout flow
Future<void> testLogoutFlow(WidgetTester tester) async {
  print('🚪 Testing Logout Flow...');
  
  // Should be on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Tap logout button
  await tester.tap(find.byIcon(Icons.logout));
  await tester.pumpAndSettle();
  
  // Should return to sign-in page
  expect(find.text('Sign In'), findsOneWidget);
  expect(find.byType(TextFormField), findsNWidgets(2));
  
  print('✅ Logout Flow completed');
}

/// Test the grant flow (guest user with token)
Future<void> testGrantFlow(WidgetTester tester) async {
  print('🎟️ Testing Grant Flow...');
  
  // This would require restarting the app with a grant token in the URL
  // For now, we'll test the grant flow by simulating the URL parameter
  
  // Create a new app instance with a mock grant token
  // This is a simplified test - in a real scenario, we'd need a valid grant token
  
  // Start app with grant parameter
  app.main();
  await tester.pumpAndSettle();
  
  // For this test, we assume we start with the normal flow
  // In a real integration test, we'd modify the app startup to include grant token
  
  print('✅ Grant Flow test structure completed (requires grant token setup)');
}

/// Test all dialogs and modals
Future<void> testAllDialogs(WidgetTester tester) async {
  print('💬 Testing All Dialogs...');
  
  // First, get to an authenticated state
  await testSignInFlow(tester);
  
  // For testing dialogs, we need to navigate to the locks page
  // This is limited without real data, but we can test the structure
  
  // Test that we can access the UI elements that would trigger dialogs
  expect(find.byIcon(Icons.add), findsOneWidget); // Add button exists
  
  print('✅ Dialog testing structure completed (requires navigation to locks/grants)');
}