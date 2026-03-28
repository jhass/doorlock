import 'env_config_platform.dart' as platform;

class EnvConfig {
  static String get pocketBaseUrl {
    // Allow override via --dart-define=POCKETBASE_URL=... (used by integration tests in Chrome)
    const defined = String.fromEnvironment('POCKETBASE_URL');
    if (defined.isNotEmpty) return defined;

    // Production: read from window.env injected by docker-entrypoint.sh via env.js
    final url = platform.readWindowPocketBaseUrl();
    return url != null && url.isNotEmpty ? url : 'http://127.0.0.1:8080';
  }
}
