/// Environment configuration interface
abstract class EnvironmentConfig {
  String get pocketBaseUrl;
}

/// Web-specific environment configuration
class WebEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl {
    // This would use dart:js_interop in a real web environment
    // For testing, we'll use a fallback
    return const String.fromEnvironment('POCKETBASE_URL', defaultValue: 'http://127.0.0.1:8080');
  }
}

/// Test environment configuration
class TestEnvironmentConfig implements EnvironmentConfig {
  final String _url;
  
  TestEnvironmentConfig(this._url);
  
  @override
  String get pocketBaseUrl => _url;
}

/// Default environment configuration
class DefaultEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl => 'http://127.0.0.1:8080';
}

class EnvConfig {
  static EnvironmentConfig _config = DefaultEnvironmentConfig();
  
  static void setConfig(EnvironmentConfig config) {
    _config = config;
  }
  
  static String get pocketBaseUrl => _config.pocketBaseUrl;
}
