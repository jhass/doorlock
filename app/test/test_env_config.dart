import 'package:doorlock/env_config.dart';

/// Test environment configuration
class TestEnvironmentConfig implements EnvironmentConfig {
  final String _url;
  
  TestEnvironmentConfig(this._url);
  
  @override
  String get pocketBaseUrl => _url;
}