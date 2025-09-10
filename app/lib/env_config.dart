/// Environment configuration interface
abstract class EnvironmentConfig {
  String get pocketBaseUrl;
}

/// Web-specific environment configuration that reads from window.env
class WebEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl {
    // Use compile-time environment variable or default
    // In web deployments, this should be set via --dart-define during build
    // or through window.env loaded by env.js
    return const String.fromEnvironment('POCKETBASE_URL', defaultValue: 'http://127.0.0.1:8080');
  }
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
