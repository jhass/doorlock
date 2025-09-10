import 'window_service.dart';

/// Stub window service for non-web platforms
class WebWindowService implements WindowService {
  @override
  void openWindow(String url) {
    // Fallback for non-web platforms - just print the URL
    print('Cannot open window on this platform: $url');
  }
}