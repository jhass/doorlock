import 'dart:js_interop';
import 'env_config.dart';

@JS('window.env')
external JSObject? get windowEnv;

@JS()
@anonymous
extension type EnvObject._(JSObject _) implements JSObject {
  external String? get pocketbaseUrl;
}

/// Web-specific environment configuration that reads from window.env
class WebEnvironmentConfig implements EnvironmentConfig {
  @override
  String get pocketBaseUrl {
    try {
      final env = windowEnv;
      if (env != null) {
        final envObj = env as EnvObject;
        final url = envObj.pocketbaseUrl;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    } catch (e) {
      // Fallback to default if accessing window.env fails
    }
    return 'http://127.0.0.1:8080';
  }
}