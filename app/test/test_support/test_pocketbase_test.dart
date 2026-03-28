import 'package:flutter_test/flutter_test.dart';

import '../../test_support/test_pocketbase.dart';

void main() {
  test('TestPocketBase boots and authenticates the superuser', () async {
    final pb = await TestPocketBase.start();
    addTearDown(pb.stop);

    expect(pb.baseUrl, startsWith('http://localhost:'));
    expect(pb.adminClient.authStore.isValid, isTrue);
  });
}