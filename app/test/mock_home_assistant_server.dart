import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Mock Home Assistant server for integration testing
class MockHomeAssistantServer {
  static HttpServer? _server;
  static final List<Map<String, dynamic>> _apiCalls = [];
  static final Map<String, bool> _validTokens = {};
  static final List<String> _lockEntities = [];

  /// Start the mock Home Assistant server
  static Future<void> start({int port = 8123}) async {
    _server = await HttpServer.bind('localhost', port);
    // ignore: avoid_print
    print('Mock Home Assistant server started on http://localhost:$port');

    await for (HttpRequest request in _server!) {
      await _handleRequest(request);
    }
  }

  /// Stop the mock Home Assistant server
  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('Mock Home Assistant server stopped');
  }

  /// Reset all server state
  static void reset() {
    _apiCalls.clear();
    _validTokens.clear();
    _lockEntities.clear();
  }

  /// Add a valid access token
  static void addValidToken(String token, List<String> lockEntities) {
    _validTokens[token] = true;
    _lockEntities.addAll(lockEntities);
  }

  /// Remove a token (making it invalid)
  static void removeToken(String token) {
    _validTokens.remove(token);
  }

  /// Get all API calls made to this server
  static List<Map<String, dynamic>> getApiCalls() => List.from(_apiCalls);

  /// Clear API call history
  static void clearApiCalls() => _apiCalls.clear();

  /// Add a mock API call for testing (simulates backend calls)
  static void addMockApiCall(Map<String, dynamic> apiCall) {
    _apiCalls.add(apiCall);
  }

  /// Handle incoming HTTP requests
  static Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for browser requests
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    // Handle preflight requests
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    // Record the API call
    final apiCall = <String, dynamic>{
      'method': request.method,
      'path': request.uri.path,
      'query': request.uri.queryParameters,
      'headers': <String, String>{},
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Convert headers to map
    request.headers.forEach((name, values) {
      (apiCall['headers'] as Map<String, String>)[name] = values.join(', ');
    });

    // Read body for POST requests
    if (request.method == 'POST' || request.method == 'PUT') {
      final body = await utf8.decoder.bind(request).join();
      if (body.isNotEmpty) {
        try {
          apiCall['body'] = jsonDecode(body);
        } catch (e) {
          apiCall['body'] = body;
        }
      }
    }

    _apiCalls.add(apiCall);

    try {
      await _routeRequest(request, apiCall);
    } catch (e) {
      print('Error handling request: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Route requests to appropriate handlers
  static Future<void> _routeRequest(HttpRequest request, Map<String, dynamic> apiCall) async {
    final path = request.uri.path;

    if (path == '/api/services/lock/open') {
      await _handleLockOpen(request, apiCall);
    } else if (path == '/auth/token') {
      await _handleTokenRefresh(request, apiCall);
    } else if (path == '/api/states') {
      await _handleGetStates(request);
    } else if (path.startsWith('/api/states/')) {
      await _handleGetState(request);
    } else if (path == '/api/config') {
      await _handleGetConfig(request);
    } else if (path == '/auth/authorize') {
      await _handleOAuthAuthorize(request);
    } else if (path == '/auth') {
      await _handleOAuth(request);
    } else {
      await _handleNotFound(request);
    }
  }

  /// Handle lock opening requests
  static Future<void> _handleLockOpen(HttpRequest request, Map<String, dynamic> apiCall) async {
    final authHeader = request.headers.value('Authorization');
    
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      request.response.statusCode = 401;
      request.response.write(jsonEncode({'message': 'Unauthorized'}));
      await request.response.close();
      return;
    }

    final token = authHeader.substring(7);
    if (!_validTokens.containsKey(token)) {
      request.response.statusCode = 401;
      request.response.write(jsonEncode({'message': 'Invalid or expired token'}));
      await request.response.close();
      return;
    }

    final body = apiCall['body'];
    final entityId = body is Map ? body['entity_id'] : null;
    
    if (entityId == null) {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({'message': 'Missing entity_id'}));
      await request.response.close();
      return;
    }

    if (!_lockEntities.contains(entityId)) {
      request.response.statusCode = 404;
      request.response.write(jsonEncode({'message': 'Entity not found'}));
      await request.response.close();
      return;
    }

    // Success response
    request.response.statusCode = 200;
    request.response.write(jsonEncode([{
      'entity_id': entityId,
      'state': 'unlocked'
    }]));
    await request.response.close();
  }

  /// Handle token refresh requests
  static Future<void> _handleTokenRefresh(HttpRequest request, Map<String, dynamic> apiCall) async {
    // Simulate token refresh endpoint
    request.response.statusCode = 200;
    request.response.write(jsonEncode({
      'access_token': 'refreshed_access_token',
      'token_type': 'Bearer',
      'expires_in': 3600
    }));
    await request.response.close();
  }

  /// Handle getting all states
  static Future<void> _handleGetStates(HttpRequest request) async {
    request.response.statusCode = 200;
    final states = _lockEntities.map((entityId) => {
      'entity_id': entityId,
      'state': 'locked',
      'attributes': {
        'friendly_name': entityId.split('.').last.replaceAll('_', ' ').toUpperCase(),
        'device_class': 'lock'
      }
    }).toList();
    request.response.write(jsonEncode(states));
    await request.response.close();
  }

  /// Handle getting a specific state
  static Future<void> _handleGetState(HttpRequest request) async {
    final entityId = request.uri.path.substring('/api/states/'.length);
    
    if (_lockEntities.contains(entityId)) {
      request.response.statusCode = 200;
      request.response.write(jsonEncode({
        'entity_id': entityId,
        'state': 'locked',
        'attributes': {
          'friendly_name': entityId.split('.').last.replaceAll('_', ' ').toUpperCase(),
          'device_class': 'lock'
        }
      }));
    } else {
      request.response.statusCode = 404;
      request.response.write(jsonEncode({'message': 'Entity not found'}));
    }
    await request.response.close();
  }

  /// Handle config requests
  static Future<void> _handleGetConfig(HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.write(jsonEncode({
      'location_name': 'Mock Home',
      'version': '2024.1.0',
      'components': ['lock', 'oauth']
    }));
    await request.response.close();
  }

  /// Handle OAuth authorize requests
  static Future<void> _handleOAuthAuthorize(HttpRequest request) async {
    final redirectUri = request.uri.queryParameters['redirect_uri'];
    final state = request.uri.queryParameters['state'];
    
    if (redirectUri != null) {
      final authCode = 'mock_auth_code_${DateTime.now().millisecondsSinceEpoch}';
      final redirectUrl = '$redirectUri?code=$authCode&state=$state';
      
      request.response.statusCode = 302;
      request.response.headers.add('Location', redirectUrl);
    } else {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({'error': 'missing_redirect_uri'}));
    }
    await request.response.close();
  }

  /// Handle OAuth token exchange
  static Future<void> _handleOAuth(HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.write(jsonEncode({
      'access_token': 'mock_access_token',
      'token_type': 'Bearer',
      'expires_in': 3600,
      'refresh_token': 'mock_refresh_token'
    }));
    await request.response.close();
  }

  /// Handle not found requests
  static Future<void> _handleNotFound(HttpRequest request) async {
    request.response.statusCode = 404;
    request.response.write(jsonEncode({'message': 'Not Found'}));
    await request.response.close();
  }
}