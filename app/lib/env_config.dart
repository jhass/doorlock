import 'env_config_web.dart' if (dart.library.io) 'env_config_stub.dart';

/// Environment configuration interface
abstract class EnvironmentConfig {
  String get pocketBaseUrl;
}

/// Default environment configuration
class DefaultEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl => 'http://127.0.0.1:8080';
}

class EnvConfig {
  static EnvironmentConfig _config = WebEnvironmentConfig();
  
  static void setConfig(EnvironmentConfig config) {
    _config = config;
  }
  
  static String get pocketBaseUrl => _config.pocketBaseUrl;
}
