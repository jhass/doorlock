import 'dart:convert';
import 'dart:io';

/// Mock Home Assistant server for integration testing
class MockHomeAssistantServer {
  static HttpServer? _server;
  static const int port = 8123;
  
  // Track API calls for verification
  static List<Map<String, dynamic>> _apiCalls = [];
  static Map<String, List<String>> _validTokens = {
    'valid_token': ['lock.front_door', 'lock.back_door'],
    'expired_token': [],
    'invalid_token': [],
  };
  static String? _lastInvalidTokenError;
  
  static Future<void> start() async {
    if (_server != null) return;
    
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('🏠 Mock Home Assistant server started on http://localhost:$port');
    
    // Clear previous calls and reset state
    _apiCalls.clear();
    _lastInvalidTokenError = null;
    
    // Handle requests asynchronously without blocking
    _server!.listen(_handleRequest);
  }
  
  /// Get recorded API calls for verification
  static List<Map<String, dynamic>> getApiCalls() => List.from(_apiCalls);
  
  /// Clear recorded API calls
  static void clearApiCalls() => _apiCalls.clear();
  
  /// Set valid tokens for testing
  static void setValidToken(String token, List<String> allowedEntities) {
    _validTokens[token] = allowedEntities;
  }
  
  /// Get last invalid token error
  static String? getLastInvalidTokenError() => _lastInvalidTokenError;
  
  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('🏠 Mock Home Assistant server stopped');
  }
  
  static Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    final authHeader = request.headers.value('Authorization');
    
    // Record API call for verification
    _apiCalls.add({
      'method': method,
      'path': path,
      'headers': <String, List<String>>{
        'authorization': authHeader != null ? [authHeader] : [],
        'content-type': request.headers.contentType?.toString() != null ? [request.headers.contentType!.toString()] : [],
      },
      'timestamp': DateTime.now().toIso8601String(),
      'authorization': authHeader,
    });
    
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }
    
    // Validate authorization for protected endpoints
    if (path.startsWith('/api/') && path != '/api/' && !_validateAuth(authHeader, path)) {
      request.response.statusCode = 401;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'message': _lastInvalidTokenError ?? 'Unauthorized'
      }));
      await request.response.close();
      return;
    }
    
    try {
      switch (path) {
        case '/api/':
          await _handleApiInfo(request);
          break;
        case '/api/states':
          await _handleStates(request);
          break;
        case '/api/services/lock/unlock':
          await _handleUnlock(request);
          break;
        case '/api/services/lock/open':
          await _handleUnlock(request); // Same handling as unlock
          break;
        case '/auth/authorize':
          await _handleAuthorize(request);
          break;
        case '/auth/token':
          await _handleToken(request);
          break;
        default:
          if (path.startsWith('/api/states/')) {
            await _handleEntityState(request);
          } else {
            request.response.statusCode = 404;
            await request.response.close();
          }
      }
    } catch (e) {
      print('Error handling request: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }
  
  static bool _validateAuth(String? authHeader, String path) {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      _lastInvalidTokenError = 'Missing or invalid authorization header';
      return false;
    }
    
    final token = authHeader.substring('Bearer '.length);
    
    // Check for expired token
    if (token == 'expired_token') {
      _lastInvalidTokenError = 'Token has expired';
      return false;
    }
    
    // Check for invalid token
    if (token == 'invalid_token') {
      _lastInvalidTokenError = 'Invalid token';
      return false;
    }
    
    // Check if token is valid and has access to requested entity
    if (!_validTokens.containsKey(token)) {
      _lastInvalidTokenError = 'Unknown token';
      return false;
    }
    
    return true;
  }
  
  static Future<void> _handleApiInfo(HttpRequest request) async {
    final response = {
      'message': 'API running.',
      'version': '2023.12.0',
    };
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }
  
  static Future<void> _handleStates(HttpRequest request) async {
    final states = [
      {
        'entity_id': 'lock.front_door',
        'state': 'locked',
        'attributes': {
          'friendly_name': 'Front Door Lock',
          'device_class': 'lock',
        },
        'last_changed': DateTime.now().toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
      },
      {
        'entity_id': 'lock.back_door',
        'state': 'locked',
        'attributes': {
          'friendly_name': 'Back Door Lock',
          'device_class': 'lock',
        },
        'last_changed': DateTime.now().toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
      },
    ];
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(states));
    await request.response.close();
  }
  
  static Future<void> _handleEntityState(HttpRequest request) async {
    final entityId = request.uri.pathSegments.last;
    
    final state = {
      'entity_id': entityId,
      'state': 'locked',
      'attributes': {
        'friendly_name': entityId.replaceAll('_', ' ').replaceAll('lock.', '').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ') + ' Lock',
        'device_class': 'lock',
      },
      'last_changed': DateTime.now().toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(state));
    await request.response.close();
  }
  
  static Future<void> _handleUnlock(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final response = [
      {
        'entity_id': data['entity_id'],
        'state': 'changed',
      }
    ];
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }
  
  static Future<void> _handleAuthorize(HttpRequest request) async {
    final params = request.uri.queryParameters;
    final redirectUri = params['redirect_uri'];
    final state = params['state'];
    
    // Simulate OAuth authorization
    final authCode = 'mock_auth_code_${DateTime.now().millisecondsSinceEpoch}';
    final redirectUrl = '$redirectUri?code=$authCode&state=$state';
    
    request.response.statusCode = 302;
    request.response.headers.add('Location', redirectUrl);
    await request.response.close();
  }
  
  static Future<void> _handleToken(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    
    // Parse form-encoded data (grant_type=refresh_token&refresh_token=...)
    final params = <String, String>{};
    for (final pair in body.split('&')) {
      final keyValue = pair.split('=');
      if (keyValue.length == 2) {
        params[Uri.decodeComponent(keyValue[0])] = Uri.decodeComponent(keyValue[1]);
      }
    }
    
    // Check grant type and code to determine token validity
    String tokenType = 'valid_token';
    if (params['code'] == 'expired_code' || params['refresh_token']?.contains('expired') == true) {
      tokenType = 'expired_token';
    } else if (params['code'] == 'invalid_code' || params['refresh_token']?.contains('invalid') == true) {
      tokenType = 'invalid_token';
    }
    
    final response = {
      'access_token': '${tokenType}_${DateTime.now().millisecondsSinceEpoch}',
      'token_type': 'Bearer',
      'expires_in': tokenType == 'expired_token' ? 0 : 3600,
      'refresh_token': 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
    };
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }
}