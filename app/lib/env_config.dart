import 'dart:js_interop';

@JS('window.env')
external JSObject? get _env;

extension EnvJSObjectExt on JSObject {
  external String? get POCKETBASE_URL;
}

class EnvConfig {
  static String get pocketBaseUrl {
    final env = _env;
    if (env == null) return 'http://127.0.0.1:8080';
    final url = env.POCKETBASE_URL;
    return url != null && url.isNotEmpty ? url : 'http://127.0.0.1:8080';
  }
}
