import 'window_service_web.dart' if (dart.library.io) 'window_service_stub.dart';

/// Interface for platform-specific window operations
abstract class WindowService {
  void openWindow(String url);
}

// Global window service for dependency injection
WindowService _windowService = WebWindowService();

void setWindowService(WindowService service) {
  _windowService = service;
}

WindowService getWindowService() => _windowService;