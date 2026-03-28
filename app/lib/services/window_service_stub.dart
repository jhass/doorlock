import 'window_service.dart';

/// VM / non-web stub: silently ignores the call.
/// Selected by [window_service_platform.dart] on non-web platforms.
class DefaultWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {}
}
