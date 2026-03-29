import 'package:doorlock/grants_sheet.dart';
import 'package:doorlock/grant_token_encoder.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> tapGrantShareIcon(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final grantTile = find.ancestor(
      of: find.text('Test Grant'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: grantTile, matching: find.byIcon(Icons.share)),
    );
    await tester.pumpAndSettle();
  }

  Finder actionInSection(String sectionTitle, String actionText) {
    final section = find.ancestor(
      of: find.text(sectionTitle),
      matching: find.byType(Card),
    );
    return find.descendant(
      of: section,
      matching: find.widgetWithText(TextButton, actionText),
    );
  }

  testWidgets('shows seeded grant in list', (tester) async {
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
        .toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('Test Grant'), findsOneWidget);
  });

  testWidgets('deletes a grant', (tester) async {
    final toDelete = await fixtures!.createGrant(lockId, name: 'Delete Me');
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
        .toJson();

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

  testWidgets('share button opens share sheet with both options', (
    tester,
  ) async {
    final mockShare = MockShareService();
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
        .toJson();

    await tester.pumpWidget(
      buildGrantsSheet(lock: lock, shareService: mockShare),
    );
    await tapGrantShareIcon(tester);

    expect(find.text('Share Grant'), findsOneWidget);
    expect(find.text('Requires QR scan at the door'), findsOneWidget);
    expect(find.text('No scan required (remote open)'), findsOneWidget);
    expect(mockShare.calls, isEmpty);
  });

  testWidgets(
    'missing lock token shows snackbar and does not open share sheet',
    (tester) async {
      final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
          .toJson();
      lock.remove('identification_token');

      await tester.pumpWidget(buildGrantsSheet(lock: lock));
      await tester.pumpAndSettle();

      await tapGrantShareIcon(tester);

      expect(
        find.text('Unable to share this grant for remote open.'),
        findsOneWidget,
      );
      expect(find.text('Share Grant'), findsNothing);
    },
  );

  testWidgets('share and copy actions generate typed links for both options', (
    tester,
  ) async {
    final mockShare = MockShareService();
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
        .toJson();
    String? clipboardText;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = (call.arguments as Map<Object?, Object?>);
            clipboardText = args['text'] as String?;
          }
          return null;
        });

    await tester.pumpWidget(
      buildGrantsSheet(lock: lock, shareService: mockShare),
    );
    await tapGrantShareIcon(tester);

    await tester.tap(
      actionInSection('Requires QR scan at the door', 'Share').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      actionInSection('No scan required (remote open)', 'Share').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      actionInSection('Requires QR scan at the door', 'Copy').first,
    );
    await tester.pumpAndSettle();

    final firstCopied = clipboardText;

    await tester.tap(
      actionInSection('No scan required (remote open)', 'Copy').first,
    );
    await tester.pumpAndSettle();

    expect(mockShare.calls.length, equals(2));
    final scanShareUri = Uri.parse(mockShare.calls[0]);
    final noScanShareUri = Uri.parse(mockShare.calls[1]);
    final scanSharePayload = GrantTokenEncoder.decode(
      scanShareUri.queryParameters['grant']!,
    );
    final noScanSharePayload = GrantTokenEncoder.decode(
      noScanShareUri.queryParameters['grant']!,
    );
    expect(scanSharePayload, isA<ScanRequiredPayload>());
    expect(
      (scanSharePayload as ScanRequiredPayload).grantToken,
      grantRecord['token'],
    );
    expect(noScanSharePayload, isA<NoScanPayload>());
    final noScanPayload = noScanSharePayload as NoScanPayload;
    expect(
      noScanPayload.grantToken,
      grantRecord['token'],
    );
    expect(
      noScanPayload.lockToken,
      lock['identification_token'],
    );

    final firstCopyPayload = GrantTokenEncoder.decode(
      Uri.parse(firstCopied!).queryParameters['grant']!,
    );
    final secondCopyPayload = GrantTokenEncoder.decode(
      Uri.parse(clipboardText!).queryParameters['grant']!,
    );
    expect(firstCopyPayload, isA<ScanRequiredPayload>());
    expect(secondCopyPayload, isA<NoScanPayload>());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('share failure falls back to clipboard and shows snackbar', (
    tester,
  ) async {
    final lock = (await userPb.collection('doorlock_locks').getOne(lockId))
        .toJson();
    String? clipboardText;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = (call.arguments as Map<Object?, Object?>);
            clipboardText = args['text'] as String?;
          }
          return null;
        });

    await tester.pumpWidget(
      buildGrantsSheet(lock: lock, shareService: ThrowingShareService()),
    );
    await tapGrantShareIcon(tester);

    await tester.tap(
      actionInSection('No scan required (remote open)', 'Share').first,
    );
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(find.text('Deeplink copied to clipboard'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

class ThrowingShareService implements ShareService {
  @override
  Future<void> shareText(String text) async {
    throw Exception('share failed');
  }
}
