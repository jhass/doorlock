import 'dart:convert';
import 'dart:io';

/// A minimal mock of the Home Assistant HTTP API.
/// Handles the three endpoints called by PocketBase hooks:
///   POST /auth/token       - token endpoint (OAuth2 + refresh)
///   GET  /api/states       - entity state list
///   POST /api/services/lock/open - lock service call
///
/// Records all received requests for assertion use.
class MockHomeAssistantServer {
  final HttpServer _server;
  final List<HttpRequest> _recordedRequests = [];
  final Map<String, _OverrideResponse> _nextOverrides = {};

  // Configurable entity list returned by GET /api/states.
  List<Map<String, dynamic>> entities;

  MockHomeAssistantServer._(this._server, {required this.entities}) {
    _serve();
  }

  /// Starts the server on a random available port.
  static Future<MockHomeAssistantServer> start({
    List<Map<String, dynamic>>? entities,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return MockHomeAssistantServer._(
      server,
      entities:
          entities ??
          [
            {
              'entity_id': 'lock.front_door',
              'state': 'locked',
              'attributes': {
                'friendly_name': 'Front Door',
                'supported_features': 1,
              },
            },
          ],
    );
  }

  int get port => _server.port;
  String get baseUrl => 'http://localhost:$port';
  List<HttpRequest> get recordedRequests => List.unmodifiable(_recordedRequests);

  /// Override the response for the next request matching [path].
  /// After one use the override is cleared.
  void setNextResponseFor(String path, int statusCode, Map<String, dynamic> body) {
    _nextOverrides[path] = _OverrideResponse(statusCode, body);
  }

  void _serve() {
    _server.listen((req) async {
      _recordedRequests.add(req);

      final path = req.uri.path;
      final override = _nextOverrides.remove(path);

      if (override != null) {
        req.response
          ..statusCode = override.statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(override.body));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path == '/auth/token') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'access_token': 'test-token-refreshed',
              'expires_in': 3600,
              'token_type': 'Bearer',
              'refresh_token': 'test-refresh',
            }),
          );
      } else if (req.method == 'GET' && path == '/api/states') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(entities));
      } else if (req.method == 'POST' && path == '/api/services/lock/open') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, dynamic>{}));
      } else {
        req.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
      }

      await req.response.close();
    });
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

class _OverrideResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  _OverrideResponse(this.statusCode, this.body);
}
