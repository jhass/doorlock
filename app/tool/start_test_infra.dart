import 'dart:io';

import '../test_support/mock_ha_server.dart';
import '../test_support/test_fixtures.dart';
import '../test_support/test_pocketbase.dart';

Future<void> main() async {
  Process? webDriver;

  final webDriverBinary =
      Platform.environment['CHROMEDRIVER_BINARY'] ?? 'chromedriver';
  print('[infra] Starting WebDriver ($webDriverBinary)...');
  try {
    webDriver = await Process.start(webDriverBinary, ['--port=4444']);
    webDriver.stdout.listen((data) => stdout.add(data));
    webDriver.stderr.listen((data) => stderr.add(data));
    await Future<void>.delayed(const Duration(seconds: 2));
  } on ProcessException catch (e) {
    stderr.writeln('[infra] Failed to start WebDriver: $e');
    exit(1);
  }

  print('[infra] Starting MockHomeAssistantServer...');
  final ha = await MockHomeAssistantServer.start();
  print('[infra] MockHA listening on ${ha.baseUrl}');

  print('[infra] Starting PocketBase...');
  final pb = await TestPocketBase.start();
  print('[infra] PocketBase ready at ${pb.baseUrl}');

  final fixtures = TestFixtures(adminClient: pb.adminClient, mockHa: ha);
  final userId = await fixtures.createUser(
    email: 'inttest@test.local',
    password: 'inttestpassword',
  );
  final haId = await fixtures.createHomeAssistant(userId);
  final lock = await fixtures.createLock(haId);
  final lockId = lock['id'] as String;
  final lockToken = lock['identification_token'] as String;
  final grant = await fixtures.createGrant(lockId);
  final grantToken = grant['token'] as String;

  print('[infra] Test data seeded. Running integration tests...');

  final targets = <String>[
    'integration_test/auth_flow_test.dart',
    'integration_test/admin_flow_test.dart',
    'integration_test/grants_flow_test.dart',
    'integration_test/open_door_flow_test.dart',
  ];

  var exitCode = 0;
  for (final target in targets) {
    print('[infra] Running $target');
    final result = await Process.start(
      'flutter',
      [
        'drive',
        '--driver=test_driver/integration_test.dart',
        '--target=$target',
        '-d',
        'chrome',
        '--dart-define=POCKETBASE_URL=${pb.baseUrl}',
        '--dart-define=HA_URL=${ha.baseUrl}',
        '--dart-define=TEST_USER_EMAIL=inttest@test.local',
        '--dart-define=TEST_USER_PASSWORD=inttestpassword',
        '--dart-define=TEST_HA_ID=$haId',
        '--dart-define=TEST_HA_URL=${ha.baseUrl}',
        '--dart-define=TEST_LOCK_ID=$lockId',
        '--dart-define=TEST_LOCK_TOKEN=$lockToken',
        '--dart-define=TEST_GRANT_TOKEN=$grantToken',
      ],
      runInShell: false,
    );

    result.stdout.listen(stdout.add);
    result.stderr.listen(stderr.add);

    exitCode = await result.exitCode;
    if (exitCode != 0) {
      print('[infra] $target failed with exit code $exitCode');
      break;
    }
  }

  print('[infra] Tests finished with exit code $exitCode. Cleaning up...');
  await pb.stop();
  await ha.stop();
  webDriver.kill();

  exit(exitCode);
}
