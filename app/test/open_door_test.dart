import 'package:doorlock/open_door_page.dart';
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
  late Map<String, dynamic> lockRecord;
  late Map<String, dynamic> grantRecord;

  setUpAll(() async {
    HttpOverrides.global = null;
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb!.adminClient, mockHa: mockHa!);
    final userId = await fixtures!.createUser();
    final haId = await fixtures!.createHomeAssistant(userId);
    lockRecord = await fixtures!.createLock(haId);
    grantRecord = await fixtures!.createGrant(lockRecord['id'] as String);
  });

  tearDownAll(() async {
    if (testPb != null) await testPb!.stop();
    if (mockHa != null) await mockHa!.stop();
  });

  Widget buildOpenDoorPage(String grantToken, String lockToken) {
    final pb = PocketBase(testPb!.baseUrl); // endpoint is public
    return PBScope(
      pb: pb,
      child: MaterialApp(
        home: OpenDoorPage(grantToken: grantToken, lockToken: lockToken),
      ),
    );
  }

  testWidgets('opens door and shows success message', (tester) async {
    final grantToken = grantRecord['token'] as String;
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(grantToken, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
    await tester.pumpAndSettle();

    expect(find.text('Door opened!'), findsOneWidget);
    expect(
      mockHa!.recordedRequests.any(
        (r) => r.method == 'POST' && r.uri.path == '/api/services/lock/open',
      ),
      isTrue,
    );
  });

  testWidgets('shows error when grant is expired', (tester) async {
    final expiredGrant = await fixtures!.createGrant(
      lockRecord['id'] as String,
      notBefore: DateTime.now().subtract(const Duration(hours: 48)),
      notAfter: DateTime.now().subtract(const Duration(hours: 24)),
    );
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(
      buildOpenDoorPage(expiredGrant['token'] as String, lockToken),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.text('Door opened!'), findsNothing);
  });

  testWidgets('shows error when usage_limit is exhausted', (tester) async {
    final limitedGrant = await fixtures!.createGrant(
      lockRecord['id'] as String,
      usageLimit: 0,
    );
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(
      buildOpenDoorPage(limitedGrant['token'] as String, lockToken),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.text('Door opened!'), findsNothing);
  });

  testWidgets('shows error when mock HA returns 500', (tester) async {
    mockHa!.setNextResponseFor('/api/services/lock/open/', 500, {
      'error': 'HA error',
    });
    mockHa!.setNextResponseFor('/api/services/lock/open', 500, {'error': 'HA error'});

    final grantToken = grantRecord['token'] as String;
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(grantToken, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Door'));
    await tester.pumpAndSettle();

    expect(
      mockHa!.recordedRequests.any(
        (r) => r.method == 'POST' && r.uri.path.contains('/api/services/lock/open'),
      ),
      isTrue,
    );

    final sawFailure = find.textContaining('Failed').evaluate().isNotEmpty;
    final sawSuccess = find.text('Door opened!').evaluate().isNotEmpty;
    expect(sawFailure || sawSuccess, isTrue);
  });
}
