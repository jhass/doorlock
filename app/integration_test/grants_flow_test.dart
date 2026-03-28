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

  Future<void> signInAndNavigateToLocks(WidgetTester tester) async {
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
  }

  testWidgets('opens grants sheet and shows seeded grant', (tester) async {
    await signInAndNavigateToLocks(tester);

    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();

    expect(find.text('Test Grant'), findsOneWidget);
  });

  testWidgets('Add Grant form creates a new grant', (tester) async {
    await signInAndNavigateToLocks(tester);
    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add Grant'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Integration Grant',
    );

    await tester.tap(find.widgetWithText(TextFormField, 'Not before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextFormField, 'Not after'));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Integration Grant'), findsOneWidget);
  });
}
