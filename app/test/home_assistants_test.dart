import 'package:doorlock/home_assistants_page.dart';
import 'package:doorlock/locks_page.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:io';

import '../test_support/mock_ha_server.dart';
import '../test_support/test_fixtures.dart';
import '../test_support/test_pocketbase.dart';

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  TestPocketBase? testPb;
  MockHomeAssistantServer? mockHa;
  TestFixtures? fixtures;
  late PocketBase userPb;

  setUpAll(() async {
    HttpOverrides.global = null;
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb!.adminClient, mockHa: mockHa!);
    final userId = await fixtures!.createUser();
    await fixtures!.createHomeAssistant(userId);
    userPb = await fixtures!.userClient();
  });

  tearDownAll(() async {
    if (testPb != null) await testPb!.stop();
    if (mockHa != null) await mockHa!.stop();
  });

  testWidgets('lists seeded home assistant record', (tester) async {
    final assistants = await userPb.collection('doorlock_homeassistants').getFullList();

    await tester.pumpWidget(
      PBScope(
        pb: userPb,
        child: MaterialApp(
          home: HomeAssistantsPage(
            assistants: assistants.map((r) => r.toJson()).toList(),
            onSignOut: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.text(mockHa!.baseUrl), findsOneWidget);
  });

  testWidgets('tapping HA record navigates to LocksPage', (tester) async {
    final assistants = await userPb.collection('doorlock_homeassistants').getFullList();

    await tester.pumpWidget(
      PBScope(
        pb: userPb,
        child: MaterialApp(
          home: HomeAssistantsPage(
            assistants: assistants.map((r) => r.toJson()).toList(),
            onSignOut: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(mockHa!.baseUrl));
    await tester.pumpAndSettle();

    expect(find.byType(LocksPage), findsOneWidget);
    expect(find.text('Locks for ${mockHa!.baseUrl}'), findsOneWidget);
  });
}
