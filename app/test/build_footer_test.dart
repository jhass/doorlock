import 'package:doorlock/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shortBuildCommit returns dev for empty input', () {
    expect(shortBuildCommit(''), 'dev');
  });

  test('shortBuildCommit truncates long commit hashes to seven chars', () {
    expect(shortBuildCommit('1234567890abcdef'), '1234567');
  });

  testWidgets('global app builder renders footer with repo link and build info', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: globalAppBuilder,
        home: const Scaffold(body: Text('Screen body')),
      ),
    );

    expect(find.text('Screen body'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Build dev'), findsOneWidget);
  });
}
