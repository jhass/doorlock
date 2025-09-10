import 'env_config.dart';

/// Stub environment configuration for non-web platforms
class WebEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl => 'http://127.0.0.1:8080';
}