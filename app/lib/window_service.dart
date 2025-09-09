/// Interface for platform-specific window operations
abstract class WindowService {
  void openWindow(String url);
}

/// Web-specific window service
class WebWindowService implements WindowService {
  @override
  void openWindow(String url) {
    // For now, just print - in real web environment would use dart:js_util
    print('Would open window: $url');
  }
}

// Global window service for dependency injection
WindowService _windowService = WebWindowService();

void setWindowService(WindowService service) {
  _windowService = service;
}

WindowService getWindowService() => _windowService;