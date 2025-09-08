import 'package:pocketbase/pocketbase.dart';

class PB {
  static PocketBase? _testInstance;
  static PocketBase? _instance;
  
  static PocketBase get instance {
    if (_testInstance != null) return _testInstance!;
    return _instance ??= PocketBase(_getDefaultUrl());
  }
  
  static String _getDefaultUrl() {
    // This is a fallback URL for when env_config is not available
    // In production, this should be overridden by proper initialization
    return 'http://127.0.0.1:8080';
  }
  
  /// Initialize with a specific URL (for production use)
  static void initialize(String url) {
    _instance = PocketBase(url);
  }
  
  /// Override the PocketBase instance for testing
  static void setTestInstance(PocketBase? testInstance) {
    _testInstance = testInstance;
  }
  
  /// Clear the test instance and return to normal operation
  static void clearTestInstance() {
    _testInstance = null;
  }
}
