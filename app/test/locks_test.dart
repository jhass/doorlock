import 'package:doorlock/locks_page.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/window_service.dart';
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
  late String haId;

  setUpAll(() async {
    HttpOverrides.global = null;
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb!.adminClient, mockHa: mockHa!);
    final userId = await fixtures!.createUser();
    haId = await fixtures!.createHomeAssistant(userId);
    await fixtures!.createLock(haId);
    userPb = await fixtures!.userClient();
  });

  tearDownAll(() async {
    if (testPb != null) await testPb!.stop();
    if (mockHa != null) await mockHa!.stop();
  });

  Widget buildLocksPage({WindowService? windowService}) {
    return PBScope(
      pb: userPb,
      child: MaterialApp(
        home: LocksPage(
          homeAssistantId: haId,
          homeAssistantUrl: mockHa!.baseUrl,
          windowService: windowService ?? NoOpWindowService(),
        ),
      ),
    );
  }

  testWidgets('shows seeded lock in list', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('lock.front_door'), findsOneWidget);
  });

  testWidgets('Add Lock fetches from mock HA and shows entity list', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);

    expect(
      mockHa!.recordedRequests.any(
        (r) => r.method == 'GET' && r.uri.path == '/api/states',
      ),
      isTrue,
    );
  });

  testWidgets('tapping entity creates a lock record and re-lists', (tester) async {
    final countBefore = (await testPb!.adminClient
            .collection('doorlock_locks')
            .getFullList(filter: 'homeassistant = "$haId"'))
        .length;

    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Front Door').last);
    await tester.pumpAndSettle();

    final countAfter = (await testPb!.adminClient
            .collection('doorlock_locks')
            .getFullList(filter: 'homeassistant = "$haId"'))
        .length;

    expect(countAfter, greaterThan(countBefore));
  });

  testWidgets('QR icon opens dialog with lock QR actions', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code).first);
    await tester.pumpAndSettle();

    expect(find.text('Lock QR Code'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
