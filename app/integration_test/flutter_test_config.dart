import 'dart:async';

import 'package:integration_test/integration_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}
