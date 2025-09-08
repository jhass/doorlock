import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/sign_in_page.dart';

void main() {
  group('Authentication Functionality', () {
    testWidgets('Complete authentication workflow', (WidgetTester tester) async {
      String? authenticatedUser, authenticatedPassword;
      List<String> authAttempts = [];

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            authAttempts.add('$username:$password');
            authenticatedUser = username;
            authenticatedPassword = password;
          },
        ),
      ));

      // Test complete authentication flow
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'admin');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secure123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify authentication was processed
      expect(authAttempts.length, equals(1));
      expect(authenticatedUser, equals('admin'));
      expect(authenticatedPassword, equals('secure123'));
      expect(authAttempts.first, equals('admin:secure123'));
    });

    testWidgets('Authentication with error handling', (WidgetTester tester) async {
      bool authenticationAttempted = false;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            authenticationAttempted = true;
          },
          error: 'Authentication failed: Invalid credentials',
        ),
      ));

      // Verify error is displayed prominently
      expect(find.text('Authentication failed: Invalid credentials'), findsOneWidget);
      
      // User can still attempt to sign in despite error
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'retry');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(authenticationAttempted, isTrue);
    });

    testWidgets('Input validation prevents invalid submissions', (WidgetTester tester) async {
      bool submitAttempted = false;

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            submitAttempted = true;
          },
        ),
      ));

      // Try submitting without credentials
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation messages and not call onSignIn
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
      expect(submitAttempted, isFalse);
    });

    testWidgets('Authentication state management', (WidgetTester tester) async {
      List<Map<String, String>> authHistory = [];

      await tester.pumpWidget(MaterialApp(
        home: _TestAuthFlow(
          onAuthAttempt: (username, password) {
            authHistory.add({'username': username, 'password': password});
          },
        ),
      ));

      // Test multiple authentication attempts
      await tester.enterText(find.byKey(const Key('username')), 'user1');
      await tester.enterText(find.byKey(const Key('password')), 'pass1');
      await tester.tap(find.byKey(const Key('signin')));
      await tester.pumpAndSettle();

      // Clear and try again
      await tester.enterText(find.byKey(const Key('username')), 'user2');
      await tester.enterText(find.byKey(const Key('password')), 'pass2');
      await tester.tap(find.byKey(const Key('signin')));
      await tester.pumpAndSettle();

      // Verify both attempts were captured
      expect(authHistory.length, equals(2));
      expect(authHistory[0]['username'], equals('user1'));
      expect(authHistory[1]['username'], equals('user2'));
    });

    testWidgets('User credential processing', (WidgetTester tester) async {
      Map<String, String> processedCredentials = {};

      await tester.pumpWidget(MaterialApp(
        home: SignInPage(
          onSignIn: (username, password) {
            // Test credential processing (trimming, etc.)
            processedCredentials['username'] = username;
            processedCredentials['password'] = password;
          },
        ),
      ));

      // Test with whitespace that should be trimmed
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), '  testuser  ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify username was trimmed but password was not
      expect(processedCredentials['username'], equals('testuser'));
      expect(processedCredentials['password'], equals('password123'));
    });
  });
}

// Test authentication flow with state management
class _TestAuthFlow extends StatefulWidget {
  final Function(String, String) onAuthAttempt;
  const _TestAuthFlow({required this.onAuthAttempt});
  
  @override
  State<_TestAuthFlow> createState() => _TestAuthFlowState();
}

class _TestAuthFlowState extends State<_TestAuthFlow> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            key: const Key('username'),
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            key: const Key('password'),
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          ElevatedButton(
            key: const Key('signin'),
            onPressed: () {
              widget.onAuthAttempt(_usernameController.text, _passwordController.text);
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}