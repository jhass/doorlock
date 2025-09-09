import 'package:doorlock/window_service.dart';

/// Test window service implementation
class TestWindowService implements WindowService {
  @override
  void openWindow(String url) {
    // Mock implementation - do nothing for tests
    print('Mock window service: would open $url');
  }
}