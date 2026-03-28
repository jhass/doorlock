import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text);
}

/// Production implementation: delegates to share_plus.
class RealShareService implements ShareService {
  @override
  Future<void> shareText(String text) async {
    await Share.share(text);
  }
}

/// Test double that records calls for assertions.
class MockShareService implements ShareService {
  final List<String> calls = [];

  @override
  Future<void> shareText(String text) async {
    calls.add(text);
  }
}
