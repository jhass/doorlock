import 'dart:async';
import 'dart:convert';
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
    // Start chromedriver first so it has time to fully initialise while we
    // set up MockHA, PocketBase, and seed test data.
    final webDriverBinary =
        Platform.environment['CHROMEDRIVER_BINARY'] ?? 'chromedriver';
    print('[infra] Starting WebDriver ($webDriverBinary)...');
    webDriver = await Process.start(webDriverBinary, ['--port=4444']);
    webDriver.stdout.drain<void>();
    // Pipe chromedriver stderr so startup errors appear in CI logs.
    webDriver.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln('[chromedriver] $line'));

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

    // By now chromedriver has had several seconds to fully initialise.
    await _waitForChromeDriver(const Duration(seconds: 30));
    print('[infra] WebDriver is ready on port 4444');

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
      // Delete any stale WebDriver sessions so the next target gets a clean
      // Chrome instance from the same chromedriver process.
      await _deleteWebDriverSessions();
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

Future<void> _waitForChromeDriver(Duration timeout) async {
  final client = HttpClient();
  final deadline = DateTime.now().add(timeout);
  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:4444/status'),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 2),
        );
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>?;
          final value = json?['value'] as Map<String, dynamic>?;
          if (value != null && value['ready'] == true) return;
        }
      } catch (_) {
        // Not ready yet.
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } finally {
    client.close();
  }
  throw TimeoutException('chromedriver did not become ready on port 4444');
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
  print('[infra] Launching $target...');
  final result = await Process.start(
    'flutter',
    [
      'drive',
      '--driver=test_driver/integration_test.dart',
      '--target=$target',
      '--no-keep-app-running',
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

  final earlyExit = Completer<int>();
  var sawSuccess = false;
  var sawFailure = false;

  result.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    stdout.writeln(line);
    if (line.contains('All tests passed!')) {
      sawSuccess = true;
      // In CI web runs, flutter drive can hang after reporting success.
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (earlyExit.isCompleted) return;
        result.kill();
        earlyExit.complete(0);
      });
    }
    if (line.contains('Some tests failed.')) {
      sawFailure = true;
      if (!earlyExit.isCompleted) {
        result.kill();
        earlyExit.complete(1);
      }
    }
  });

  result.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    stderr.writeln(line);
  });

  return Future.any([result.exitCode, earlyExit.future]).timeout(
    const Duration(minutes: 8),
    onTimeout: () {
      if (sawSuccess) {
        result.kill();
        return 0;
      }
      if (sawFailure) {
        result.kill();
        return 1;
      }
      result.kill();
      return 124;
    },
  );
}

/// Deletes all active WebDriver sessions so the next [_runDriveTarget] call
/// starts with a clean Chrome instance. Without this, the Chrome window
/// orphaned when we kill flutter drive after success stays alive and causes
/// DWDS [AppConnectionException] on the following invocation.
Future<void> _deleteWebDriverSessions() async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('http://localhost:4444/sessions'))
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>?;
    final sessions = json?['value'] as List<dynamic>?;
    if (sessions == null) return;
    for (final session in sessions) {
      final id = (session as Map<String, dynamic>?)?['id'] as String?;
      if (id == null) continue;
      try {
        final del = await client
            .deleteUrl(Uri.parse('http://localhost:4444/session/$id'))
            .timeout(const Duration(seconds: 5));
        final delResp =
            await del.close().timeout(const Duration(seconds: 10));
        await delResp.drain<void>();
        print('[infra] Closed WebDriver session $id');
      } catch (_) {}
    }
  } catch (_) {
    // If chromedriver is unreachable, nothing to clean up.
  } finally {
    client.close();
  }
}
