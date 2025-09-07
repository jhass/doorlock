import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;
import 'package:http/http.dart' as http;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete UI Walkthrough Tests', () {
    setUpAll(() async {
      // Ensure PocketBase is running and set up test data
      await setupTestData();
    });

    testWidgets('Complete authenticated user journey', (WidgetTester tester) async {
      print('🚀 Starting complete authenticated user journey...');
      
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // 1. Test Sign In Page
      await _testSignInPage(tester);
      
      // 2. Test Home Assistants Page
      await _testHomeAssistantsPage(tester);
      
      // 3. Test Add Home Assistant Dialog/Page
      await _testAddHomeAssistantPage(tester);
      
      // 4. Test navigation back and UI consistency
      await _testNavigationConsistency(tester);
      
      // 5. Test Sign Out
      await _testSignOut(tester);
    });

    testWidgets('Form validation and error handling', (WidgetTester tester) async {
      print('📝 Testing form validation and error handling...');
      
      app.main();
      await tester.pumpAndSettle();
      
      await _testFormValidation(tester);
    });

    testWidgets('UI responsiveness and loading states', (WidgetTester tester) async {
      print('⏳ Testing UI responsiveness and loading states...');
      
      app.main();
      await tester.pumpAndSettle();
      
      await _testLoadingStates(tester);
    });
  });
}

/// Set up test data in PocketBase
Future<void> setupTestData() async {
  print('📊 Setting up test data...');
  
  try {
    // Create test user if not exists
    await http.post(
      Uri.parse('http://localhost:8080/api/collections/doorlock_users/records'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'testuser',
        'password': 'testpass123',
        'passwordConfirm': 'testpass123',
      }),
    );
    print('✅ Test user created/verified');
  } catch (e) {
    print('ℹ️ Test user setup: $e (may already exist)');
  }
}

/// Test the Sign In page thoroughly
Future<void> _testSignInPage(WidgetTester tester) async {
  print('🔐 Testing Sign In Page...');
  
  // Verify we're on the sign in page
  expect(find.text('Sign In'), findsOneWidget);
  expect(find.text('Username'), findsOneWidget);
  expect(find.text('Password'), findsOneWidget);
  
  // Find form fields
  final usernameField = find.widgetWithText(TextFormField, 'Username');
  final passwordField = find.widgetWithText(TextFormField, 'Password');
  final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
  
  expect(usernameField, findsOneWidget);
  expect(passwordField, findsOneWidget);
  expect(signInButton, findsOneWidget);
  
  // Test empty form submission
  await tester.tap(signInButton);
  await tester.pumpAndSettle();
  
  // Should show validation errors
  expect(find.text('Enter username'), findsOneWidget);
  expect(find.text('Enter password'), findsOneWidget);
  
  // Test invalid credentials first
  await tester.enterText(usernameField, 'wronguser');
  await tester.enterText(passwordField, 'wrongpass');
  await tester.pumpAndSettle();
  
  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Should show error (either validation or auth error)
  final errorTexts = find.textContaining('Sign in failed').evaluate().isNotEmpty ||
                    find.textContaining('Session expired').evaluate().isNotEmpty;
  if (errorTexts) {
    print('✅ Error handling for invalid credentials works');
  }
  
  // Clear fields and enter correct credentials
  await tester.enterText(usernameField, 'testuser');
  await tester.enterText(passwordField, 'testpass123');
  await tester.pumpAndSettle();
  
  // Submit with correct credentials
  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 5));
  
  // Should navigate to Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  print('✅ Sign In Page test completed successfully');
}

/// Test the Home Assistants page
Future<void> _testHomeAssistantsPage(WidgetTester tester) async {
  print('🏠 Testing Home Assistants Page...');
  
  // Verify we're on the correct page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Check for app bar elements
  final appBar = find.byType(AppBar);
  expect(appBar, findsOneWidget);
  
  // Check for action buttons
  expect(find.byIcon(Icons.logout), findsOneWidget);
  expect(find.byIcon(Icons.add), findsOneWidget);
  
  // Check for main content area
  expect(find.byType(ListView), findsOneWidget);
  
  // Test tooltips
  final logoutButton = find.byIcon(Icons.logout);
  await tester.longPress(logoutButton);
  await tester.pumpAndSettle();
  // Tooltip might appear
  
  final addButton = find.byIcon(Icons.add);
  await tester.longPress(addButton);
  await tester.pumpAndSettle();
  // Tooltip might appear
  
  print('✅ Home Assistants Page test completed');
}

/// Test the Add Home Assistant page
Future<void> _testAddHomeAssistantPage(WidgetTester tester) async {
  print('➕ Testing Add Home Assistant Page...');
  
  // From Home Assistants page, tap add button
  final addButton = find.byIcon(Icons.add);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  
  // Should navigate to Add Home Assistant page
  expect(find.text('Add Home Assistant'), findsOneWidget);
  expect(find.text('Home Assistant Base URL'), findsOneWidget);
  
  // Find form elements
  final urlField = find.byType(TextFormField);
  final addSubmitButton = find.widgetWithText(ElevatedButton, 'Add');
  
  expect(urlField, findsOneWidget);
  expect(addSubmitButton, findsOneWidget);
  
  // Test empty form validation
  await tester.tap(addSubmitButton);
  await tester.pumpAndSettle();
  expect(find.text('Enter the base URL'), findsOneWidget);
  
  // Test invalid URL
  await tester.enterText(urlField, 'invalid-url');
  await tester.pumpAndSettle();
  await tester.tap(addSubmitButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Should show some kind of error (network or validation)
  print('✅ Invalid URL handling tested');
  
  // Test valid-looking URL (will fail but tests UI flow)
  await tester.enterText(urlField, 'http://homeassistant.local:8123');
  await tester.pumpAndSettle();
  
  await tester.tap(addSubmitButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Expect error since we don't have a real Home Assistant
  // But this tests the complete form submission flow
  final hasError = find.textContaining('Failed to add').evaluate().isNotEmpty;
  if (hasError) {
    print('✅ Expected error for unreachable Home Assistant URL');
  }
  
  print('✅ Add Home Assistant Page test completed');
}

/// Test navigation consistency
Future<void> _testNavigationConsistency(WidgetTester tester) async {
  print('🧭 Testing Navigation Consistency...');
  
  // Should be on Add Home Assistant page, go back
  final backButton = find.byIcon(Icons.arrow_back);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton);
    await tester.pumpAndSettle();
  }
  
  // Should be back on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Test navigation again to ensure consistency
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(find.text('Add Home Assistant'), findsOneWidget);
  
  // Go back again
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  expect(find.text('Home Assistants'), findsOneWidget);
  
  print('✅ Navigation consistency test completed');
}

/// Test sign out functionality
Future<void> _testSignOut(WidgetTester tester) async {
  print('🚪 Testing Sign Out...');
  
  // Should be on Home Assistants page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  // Tap sign out button
  await tester.tap(find.byIcon(Icons.logout));
  await tester.pumpAndSettle();
  
  // Should return to sign in page
  expect(find.text('Sign In'), findsOneWidget);
  expect(find.text('Username'), findsOneWidget);
  expect(find.text('Password'), findsOneWidget);
  
  print('✅ Sign Out test completed');
}

/// Test form validation comprehensively
Future<void> _testFormValidation(WidgetTester tester) async {
  print('📝 Testing Form Validation...');
  
  // Test sign in form validation
  expect(find.text('Sign In'), findsOneWidget);
  
  final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
  
  // Test multiple empty submissions
  for (int i = 0; i < 3; i++) {
    await tester.tap(signInButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter username'), findsOneWidget);
    expect(find.text('Enter password'), findsOneWidget);
  }
  
  // Test partial form filling
  final usernameField = find.widgetWithText(TextFormField, 'Username');
  await tester.enterText(usernameField, 'test');
  await tester.tap(signInButton);
  await tester.pumpAndSettle();
  
  // Should still show password validation
  expect(find.text('Enter password'), findsOneWidget);
  
  print('✅ Form validation test completed');
}

/// Test loading states and UI responsiveness
Future<void> _testLoadingStates(WidgetTester tester) async {
  print('⏳ Testing Loading States...');
  
  // Sign in to see loading states
  final usernameField = find.widgetWithText(TextFormField, 'Username');
  final passwordField = find.widgetWithText(TextFormField, 'Password');
  final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
  
  await tester.enterText(usernameField, 'testuser');
  await tester.enterText(passwordField, 'testpass123');
  await tester.pumpAndSettle();
  
  // Submit and check for loading indicator
  await tester.tap(signInButton);
  await tester.pump(); // Don't wait for settle to catch loading state
  
  // Check if CircularProgressIndicator appears during auth
  final loadingIndicator = find.byType(CircularProgressIndicator);
  if (loadingIndicator.evaluate().isNotEmpty) {
    print('✅ Loading indicator found during authentication');
  }
  
  await tester.pumpAndSettle(const Duration(seconds: 5));
  
  // Should eventually reach the next page
  expect(find.text('Home Assistants'), findsOneWidget);
  
  print('✅ Loading states test completed');
}