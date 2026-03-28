import 'package:doorlock/main.dart';
import 'package:doorlock/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const userPassword = String.fromEnvironment('TEST_USER_PASSWORD');
  const haUrl = String.fromEnvironment('TEST_HA_URL');

  setUp(() async {
    await SessionStorage.clearSession();
  });

  testWidgets('navigates into locks page and sees HA entity list on Add Lock', (
    tester,
  ) async {
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

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    expect(find.textContaining('Locks for'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Lock'));
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);
  });

  testWidgets('adds a lock and QR icon is visible', (tester) async {
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

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);
    expect(find.byTooltip('Show Lock QR'), findsOneWidget);
  });

  testWidgets('QR dialog opens with identification_token', (tester) async {
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

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show Lock QR'));
    await tester.pumpAndSettle();

    expect(find.text('Lock QR Code'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
