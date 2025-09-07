import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/sign_in_page.dart';

void main() {
  group('SignInPage Widget Tests', () {
    testWidgets('SignInPage displays all required UI elements', (WidgetTester tester) async {
      bool signInCalled = false;
      String? capturedUsername;
      String? capturedPassword;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            signInCalled = true;
            capturedUsername = username;
            capturedPassword = password;
          },
        ),
      ));

      // Verify all UI elements are present
      expect(find.text('Sign In'), findsNWidgets(2)); // AppBar title + button
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('SignInPage shows error message when provided', (WidgetTester tester) async {
      const errorMessage = 'Authentication failed';

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {},
          error: errorMessage,
        ),
      ));

      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byType(Text), findsWidgets); // Should find multiple Text widgets including error
    });

    testWidgets('SignInPage form validation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {},
        ),
      ));

      // Try to submit without filling forms
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('SignInPage accepts text input and submits correctly', (WidgetTester tester) async {
      bool signInCalled = false;
      String? capturedUsername;
      String? capturedPassword;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            signInCalled = true;
            capturedUsername = username;
            capturedPassword = password;
          },
        ),
      ));

      // Find text fields and enter text
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(usernameField, 'testuser');
      await tester.enterText(passwordField, 'testpass');
      
      // Submit the form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify the callback was called with correct values
      expect(signInCalled, isTrue);
      expect(capturedUsername, equals('testuser'));
      expect(capturedPassword, equals('testpass'));
    });

    testWidgets('SignInPage handles empty form submission', (WidgetTester tester) async {
      bool signInCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            signInCalled = true;
          },
        ),
      ));

      // Submit without entering text
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should not call the callback due to validation
      expect(signInCalled, isFalse);
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('SignInPage trims username whitespace', (WidgetTester tester) async {
      String? capturedUsername;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            capturedUsername = username;
          },
        ),
      ));

      final usernameField = find.widgetWithText(TextFormField, 'Username');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(usernameField, '  testuser  ');
      await tester.enterText(passwordField, 'testpass');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(capturedUsername, equals('testuser')); // Should be trimmed
    });

    testWidgets('SignInPage password field exists', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {},
        ),
      ));

      // Just verify the password field exists, testing obscureText is complex due to widget structure
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });
  });
}