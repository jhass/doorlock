import 'package:pocketbase/pocketbase.dart';
import 'env_config.dart';

class PB {
  static PocketBase? _testInstance;
  static PocketBase get instance => _testInstance ?? PocketBase(EnvConfig.pocketBaseUrl);
  
  /// Override the PocketBase instance for testing
  static void setTestInstance(PocketBase? testInstance) {
    _testInstance = testInstance;
  }
  
  /// Clear the test instance and return to normal operation
  static void clearTestInstance() {
    _testInstance = null;
  }
}
