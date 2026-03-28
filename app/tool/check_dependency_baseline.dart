import 'dart:convert';
import 'dart:io';

void main() {
  final appDir = Directory.current.absolute;
  final repoRoot = appDir.parent;
  final baselineFile = File('${repoRoot.path}/tool/dependency_baseline.json');
  final baseline =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;

  final flutter = baseline['flutter'] as Map<String, dynamic>;
  final pocketbase = baseline['pocketbase'] as Map<String, dynamic>;
  final chrome = baseline['chrome_for_testing'] as Map<String, dynamic>;

  final expected = <String, List<String>>{
    '${repoRoot.path}/app/Dockerfile': [flutter['docker_image'] as String],
    '${repoRoot.path}/docker/local-test/Dockerfile': [
      flutter['docker_image'] as String,
      'ARG PB_VERSION=${pocketbase['version']}',
      'ARG CFT_VERSION=${chrome['version']}',
    ],
    '${repoRoot.path}/.github/workflows/test.yml': [
      "flutter-version: '${flutter['version']}'",
      pocketbase['linux_amd64_zip'] as String,
    ],
    '${repoRoot.path}/.github/workflows/copilot-setup-steps.yml': [
      "flutter-version: '${flutter['version']}'",
    ],
  };

  final failures = <String>[];
  expected.forEach((path, snippets) {
    final content = File(path).readAsStringSync();
    for (final snippet in snippets) {
      if (!content.contains(snippet)) {
        failures.add('$path is missing: $snippet');
      }
    }
  });

  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }

  stdout.writeln('dependency baseline matches tracked files');
}