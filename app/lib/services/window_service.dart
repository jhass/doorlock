/// Abstract service for opening HTML content in a new window.
/// Use [NoOpWindowService] in tests; production uses [DefaultWindowService]
/// from [window_service_platform.dart].
abstract class WindowService {
  void openHtmlContent(String html);
}

/// No-op implementation for tests that don't care about the print action.
class NoOpWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {}
}

/// Test double that records calls for assertions.
class RecordingWindowService implements WindowService {
  final List<String> calls = [];

  @override
  void openHtmlContent(String html) {
    calls.add(html);
  }
}
