import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dependency baseline matches tracked files', () async {
    final result = await Process.run(
      'dart',
      ['run', 'tool/check_dependency_baseline.dart'],
      workingDirectory: Directory.current.path,
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  });
}