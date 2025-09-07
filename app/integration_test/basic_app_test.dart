import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Basic App Tests', () {
    testWidgets('App launches and shows sign in screen', (WidgetTester tester) async {
      print('🚀 Testing basic app launch...');
      
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify the app launched and shows the sign in screen
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      
      print('✅ App launches correctly with sign in screen');
    });

    testWidgets('Sign in form has proper validation', (WidgetTester tester) async {
      print('📝 Testing sign in form validation...');
      
      app.main();
      await tester.pumpAndSettle();

      // Find the sign in button and tap it without filling the form
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(signInButton, findsOneWidget);
      
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
      
      print('✅ Form validation works correctly');
    });

    testWidgets('Text fields accept input', (WidgetTester tester) async {
      print('⌨️ Testing text field input...');
      
      app.main();
      await tester.pumpAndSettle();

      // Find and interact with text fields
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      
      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);

      // Enter text in fields
      await tester.enterText(usernameField, 'testuser');
      await tester.enterText(passwordField, 'testpass');
      await tester.pumpAndSettle();

      // Verify text was entered
      expect(find.text('testuser'), findsOneWidget);
      // Note: Password field text might not be visible due to obscureText
      
      print('✅ Text fields accept input correctly');
    });

    testWidgets('App structure and widgets are correct', (WidgetTester tester) async {
      print('🏗️ Testing app structure...');
      
      app.main();
      await tester.pumpAndSettle();

      // Verify main app structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);

      // Verify form elements
      expect(find.byType(TextFormField), findsNWidgets(2)); // Username and password
      expect(find.byType(ElevatedButton), findsOneWidget);  // Sign in button

      print('✅ App structure is correct');
    });
  });
}