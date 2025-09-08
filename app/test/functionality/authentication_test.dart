import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/sign_in_page.dart';

void main() {
  group('Authentication Flow', () {
    testWidgets('Sign-in page displays correctly', (WidgetTester tester) async {
      bool signInCalled = false;
      String? lastUsername, lastPassword;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            signInCalled = true;
            lastUsername = username;
            lastPassword = password;
          },
        ),
      ));

      // Verify basic UI elements
      expect(find.text('Sign In'), findsWidgets); // Could appear in title and button
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('Form validation for empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SignInPage(onSignIn: (username, password) {}),
      ));

      // Try to submit empty form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('Sign-in form accepts input and submits', (WidgetTester tester) async {
      bool signInCalled = false;
      String? lastUsername, lastPassword;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            signInCalled = true;
            lastUsername = username;
            lastPassword = password;
          },
        ),
      ));

      // Enter credentials
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'testuser');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'testpass123');
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(signInCalled, isTrue);
      expect(lastUsername, equals('testuser'));
      expect(lastPassword, equals('testpass123'));
    });

    testWidgets('Error message displays when provided', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {},
          error: 'Invalid credentials',
        ),
      ));

      // Should show error message
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('Username input is trimmed', (WidgetTester tester) async {
      String? lastUsername;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            lastUsername = username;
          },
        ),
      ));

      // Enter username with whitespace
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), '  testuser  ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'testpass123');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Username should be trimmed
      expect(lastUsername, equals('testuser'));
    });
  });
}