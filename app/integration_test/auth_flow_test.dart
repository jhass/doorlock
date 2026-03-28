import 'package:doorlock/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const userPassword = String.fromEnvironment('TEST_USER_PASSWORD');

  testWidgets('app loads showing sign-in form', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('signs in and shows home page', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      userEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      userPassword,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Home Assistants'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsNothing);
  });
}
