import 'dart:async';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

/// Manages a PocketBase child process for tests.
///
/// Layout inside [_tempDir]:
///   pb_data/          <- PocketBase data directory (--dir flag)
///   pb_hooks/         <- symlink to repo's pb_hooks/
///   pb_migrations/    <- symlink to repo's pb_migrations/
///
/// PocketBase defaults hooks/migrations to siblings of pb_data, so they are
/// picked up automatically without extra flags.
class TestPocketBase {
  final Directory _tempDir;
  final Process _process;
  final int _port;

  TestPocketBase._(this._tempDir, this._process, this._port);

  String get baseUrl => 'http://localhost:$_port';

  late PocketBase _adminClient;
  PocketBase get adminClient => _adminClient;

  /// Starts a fresh PocketBase instance with the real hooks and migrations.
  ///
  /// Requires the PocketBase binary to be available via:
  ///   1. Env var POCKETBASE_BINARY
  ///   2. tools/pocketbase relative to the repo root
  ///   3. `pocketbase` on PATH
  static Future<TestPocketBase> start() async {
    final binary = _findBinary();
    final tempDir = await Directory.systemTemp.createTemp('doorlock_pb_test_');
    final dataDir = Directory('${tempDir.path}/pb_data');
    await dataDir.create();

    // Symlink real hooks and migrations as siblings of pb_data - PocketBase
    // automatically uses <parent of --dir>/pb_hooks and pb_migrations.
    final repoRoot = _repoRoot();
    await Link('${tempDir.path}/pb_hooks').create('$repoRoot/pb_hooks');
    await Link('${tempDir.path}/pb_migrations').create(
      '$repoRoot/pb_migrations',
    );

    final port = await _findFreePort();

    // Create superuser (also initializes pb_data schema).
    final upsertResult = await Process.run(binary, [
      'superuser',
      'upsert',
      'admin@test.local',
      'testpassword',
      '--dir',
      dataDir.path,
    ]);
    if (upsertResult.exitCode != 0) {
      throw Exception('pocketbase superuser upsert failed:\n${upsertResult.stderr}');
    }

    // Start server.
    final process = await Process.start(binary, [
      'serve',
      '--http=localhost:$port',
      '--dev',
      '--dir',
      dataDir.path,
    ]);

    // Pipe output so failures are visible in test output.
    process.stdout.transform(const SystemEncoding().decoder).listen(
      (line) => stderr.write('[PB] $line'),
    );
    process.stderr.transform(const SystemEncoding().decoder).listen(
      (line) => stderr.write('[PB] $line'),
    );

    final instance = TestPocketBase._(tempDir, process, port);

    // Wait for health endpoint.
    await instance._waitForReady();

    // Authenticate as superuser.
    final pb = PocketBase(instance.baseUrl);
    await pb.collection('_superusers').authWithPassword(
      'admin@test.local',
      'testpassword',
    );
    instance._adminClient = pb;

    return instance;
  }

  /// Kills the PocketBase process and removes the temporary directory.
  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
    await _tempDir.delete(recursive: true);
  }

  Future<void> _waitForReady({Duration timeout = const Duration(seconds: 20)}) async {
    final client = HttpClient();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final req = await client.getUrl(Uri.parse('$baseUrl/api/health'));
        final resp = await req.close();
        await resp.drain<void>();
        if (resp.statusCode == 200) {
          client.close();
          return;
        }
      } catch (_) {
        // Not ready yet.
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    client.close();
    throw TimeoutException('PocketBase did not become ready within $timeout');
  }

  static String _findBinary() {
    // 1. Explicit env var.
    final envBinary = Platform.environment['POCKETBASE_BINARY'];
    if (envBinary != null && File(envBinary).existsSync()) return envBinary;

    // 2. tools/pocketbase relative to repo root (installed via make install-pb-test).
    final repoBinary = '${_repoRoot()}/tools/pocketbase';
    if (File(repoBinary).existsSync()) return repoBinary;

    // 3. Assume on PATH.
    return 'pocketbase';
  }

  /// Repo root is the parent of the app/ directory.
  /// Falls back by walking upward until pb_hooks and pb_migrations are found.
  static String _repoRoot() {
    final envRoot = Platform.environment['REPO_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      return envRoot;
    }

    var dir = Directory.current.absolute;
    for (var i = 0; i < 6; i++) {
      final hooks = Directory('${dir.path}/pb_hooks');
      final migrations = Directory('${dir.path}/pb_migrations');
      if (hooks.existsSync() && migrations.existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Keep previous behavior as the final fallback.
    return Directory.current.parent.path;
  }

  static Future<int> _findFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
