import 'package:url_launcher/url_launcher.dart';

/// Mock URL launcher for testing
class MockUrlLauncher {
  static final List<String> _launchedUrls = [];
  static bool _shouldFailLaunch = false;
  static LaunchMode? _lastLaunchMode;

  /// Get list of URLs that were launched during testing
  static List<String> get launchedUrls => List.unmodifiable(_launchedUrls);
  
  /// Get the last launch mode used
  static LaunchMode? get lastLaunchMode => _lastLaunchMode;
  
  /// Configure whether launches should fail
  static void setShouldFailLaunch(bool fail) => _shouldFailLaunch = fail;
  
  /// Clear the launched URLs history
  static void clearHistory() {
    _launchedUrls.clear();
    _lastLaunchMode = null;
  }
  
  /// Mock implementation of canLaunchUrl
  static Future<bool> mockCanLaunchUrl(Uri url) async {
    if (_shouldFailLaunch) return false;
    return true;
  }
  
  /// Mock implementation of launchUrl
  static Future<bool> mockLaunchUrl(Uri url, {LaunchMode? mode}) async {
    if (_shouldFailLaunch) return false;
    
    _launchedUrls.add(url.toString());
    _lastLaunchMode = mode;
    return true;
  }
}

/// Helper function to inject mock URL launcher functions for testing
void setupMockUrlLauncher() {
  // Note: In a real implementation, you would use dependency injection
  // or a service locator pattern to replace the actual url_launcher calls
  // with these mock implementations during testing.
}