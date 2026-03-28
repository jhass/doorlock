import 'package:doorlock/grants_sheet.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/share_service.dart';
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
  late String lockId;
  late Map<String, dynamic> grantRecord;

  setUpAll(() async {
    HttpOverrides.global = null;
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb!.adminClient, mockHa: mockHa!);
    final userId = await fixtures!.createUser();
    final haId = await fixtures!.createHomeAssistant(userId);
    final lock = await fixtures!.createLock(haId);
    lockId = lock['id'] as String;
    grantRecord = await fixtures!.createGrant(lockId);
    userPb = await fixtures!.userClient();
  });

  tearDownAll(() async {
    if (testPb != null) await testPb!.stop();
    if (mockHa != null) await mockHa!.stop();
  });

  Widget buildGrantsSheet({
    required Map<String, dynamic> lock,
    ShareService? shareService,
  }) {
    return PBScope(
      pb: userPb,
      child: MaterialApp(
        home: Scaffold(
          body: GrantsSheet(
            lock: lock,
            onBack: () {},
            shareService: shareService,
          ),
        ),
      ),
    );
  }

  testWidgets('shows seeded grant in list', (tester) async {
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId)).toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('Test Grant'), findsOneWidget);
  });

  testWidgets('deletes a grant', (tester) async {
    final toDelete = await fixtures!.createGrant(lockId, name: 'Delete Me');
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId)).toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsOneWidget);

    final deleteMe = find.ancestor(
      of: find.text('Delete Me'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: deleteMe, matching: find.byIcon(Icons.delete)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);

    final exists = await testPb!.adminClient
        .collection('doorlock_grants')
        .getOne(toDelete['id'] as String)
        .then((_) => true)
        .catchError((_) => false);
    expect(exists, isFalse);
  });

  testWidgets('share button calls ShareService with URL containing grant token', (
    tester,
  ) async {
    final mockShare = MockShareService();
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId)).toJson();

    await tester.pumpWidget(
      buildGrantsSheet(lock: lock, shareService: mockShare),
    );
    await tester.pumpAndSettle();

    final grantTile = find.ancestor(
      of: find.text('Test Grant'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: grantTile, matching: find.byIcon(Icons.share)),
    );
    await tester.pumpAndSettle();

    expect(mockShare.calls.length, equals(1));
    expect(mockShare.calls.first, contains('grant=${grantRecord['token']}'));
  });
}
