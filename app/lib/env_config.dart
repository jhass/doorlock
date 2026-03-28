import 'dart:js_interop';

@JS('window.env')
external JSObject? get _env;

extension EnvJSObjectExt on JSObject {
  external String? get POCKETBASE_URL;
}

class EnvConfig {
  static String get pocketBaseUrl {
    // Allow override via --dart-define=POCKETBASE_URL=... (used by integration tests in Chrome)
    const defined = String.fromEnvironment('POCKETBASE_URL');
    if (defined.isNotEmpty) return defined;

    // Production: read from window.env injected by docker-entrypoint.sh via env.js
    final env = _env;
    if (env == null) return 'http://127.0.0.1:8080';
    final url = env.POCKETBASE_URL;
    return url != null && url.isNotEmpty ? url : 'http://127.0.0.1:8080';
  }
}
