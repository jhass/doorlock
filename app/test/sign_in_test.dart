import 'package:doorlock/main.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../test_support/mock_ha_server.dart';
import '../test_support/test_fixtures.dart';
import '../test_support/test_pocketbase.dart';

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  TestPocketBase? testPb;
  MockHomeAssistantServer? mockHa;
  TestFixtures? fixtures;

  setUpAll(() async {
    HttpOverrides.global = null;
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb!.adminClient, mockHa: mockHa!);
    await fixtures!.createUser();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStorage.clearSession();
  });

  tearDownAll(() async {
    if (testPb != null) await testPb!.stop();
    if (mockHa != null) await mockHa!.stop();
  });

  Widget buildApp(PocketBase pb) {
    return PBScope(
      pb: pb,
      child: MaterialApp(
        home: AuthGate(builder: (context) => const Text('Home')),
      ),
    );
  }

  testWidgets('shows sign-in form when not authenticated', (tester) async {
    final pb = PocketBase(testPb!.baseUrl); // fresh, no auth
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('shows error on wrong password', (tester) async {
    final pb = PocketBase(testPb!.baseUrl);
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'testuser@test.local',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in failed'), findsOneWidget);
  });

  testWidgets('signs in with valid credentials', (tester) async {
    final pb = PocketBase(testPb!.baseUrl);
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'testuser@test.local',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'testpassword',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsNothing);
  });

  testWidgets('restores session from storage - skips sign-in form', (
    tester,
  ) async {
    final pb = PocketBase(testPb!.baseUrl);
    await pb
        .collection('doorlock_users')
        .authWithPassword('testuser@test.local', 'testpassword');

    await SessionStorage.saveSession({'token': pb.authStore.token});

    final freshPb = PocketBase(testPb!.baseUrl);
    await tester.pumpWidget(buildApp(freshPb));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsNothing);
  });
}
