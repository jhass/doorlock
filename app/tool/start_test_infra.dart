import 'dart:async';
import 'dart:io';

import '../test_support/mock_ha_server.dart';
import '../test_support/test_fixtures.dart';
import '../test_support/test_pocketbase.dart';

Future<void> main() async {
  Process? webDriver;
  MockHomeAssistantServer? ha;
  TestPocketBase? pb;
  var exitCode = 1;

  try {
    final webDriverBinary =
        Platform.environment['CHROMEDRIVER_BINARY'] ?? 'chromedriver';
    print('[infra] Starting WebDriver ($webDriverBinary)...');
    webDriver = await Process.start(webDriverBinary, ['--port=4444']);
    webDriver.stdout.listen((data) => stdout.add(data));
    webDriver.stderr.listen((data) => stderr.add(data));

    await _waitForPort(4444, const Duration(seconds: 20));
    print('[infra] WebDriver is ready on port 4444');

    print('[infra] Starting MockHomeAssistantServer...');
    ha = await MockHomeAssistantServer.start();
    print('[infra] MockHA listening on ${ha.baseUrl}');

    print('[infra] Starting PocketBase...');
    pb = await TestPocketBase.start();
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

    exitCode = 0;
    for (final target in targets) {
      print('[infra] Running $target');
      exitCode = await _runDriveTarget(
        target: target,
        pocketBaseUrl: pb.baseUrl,
        haUrl: ha.baseUrl,
        haId: haId,
        lockId: lockId,
        lockToken: lockToken,
        grantToken: grantToken,
      );
      if (exitCode != 0) {
        print('[infra] $target failed with exit code $exitCode');
        break;
      }
    }
  } on ProcessException catch (e) {
    stderr.writeln('[infra] Failed to start WebDriver: $e');
    exitCode = 1;
  } on TimeoutException catch (e) {
    stderr.writeln('[infra] Timeout: $e');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('[infra] Unexpected error: $e');
    exitCode = 1;
  } finally {
    print('[infra] Tests finished with exit code $exitCode. Cleaning up...');
    if (pb != null) await pb.stop();
    if (ha != null) await ha.stop();
    if (webDriver != null) {
      webDriver.kill();
      await webDriver.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }
  }

  exit(exitCode);
}

Future<void> _waitForPort(int port, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();
      return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
  throw TimeoutException('WebDriver did not become ready on port $port');
}

Future<int> _runDriveTarget({
  required String target,
  required String pocketBaseUrl,
  required String haUrl,
  required String haId,
  required String lockId,
  required String lockToken,
  required String grantToken,
}) async {
  final result = await Process.start(
    'flutter',
    [
      'drive',
      '--driver=test_driver/integration_test.dart',
      '--target=$target',
      '-d',
      'chrome',
      '--dart-define=POCKETBASE_URL=$pocketBaseUrl',
      '--dart-define=HA_URL=$haUrl',
      '--dart-define=TEST_USER_EMAIL=inttest@test.local',
      '--dart-define=TEST_USER_PASSWORD=inttestpassword',
      '--dart-define=TEST_HA_ID=$haId',
      '--dart-define=TEST_HA_URL=$haUrl',
      '--dart-define=TEST_LOCK_ID=$lockId',
      '--dart-define=TEST_LOCK_TOKEN=$lockToken',
      '--dart-define=TEST_GRANT_TOKEN=$grantToken',
    ],
    runInShell: false,
  );

  result.stdout.listen(stdout.add);
  result.stderr.listen(stderr.add);

  return result.exitCode.timeout(
    const Duration(minutes: 8),
    onTimeout: () {
      result.kill();
      return 124;
    },
  );
}
