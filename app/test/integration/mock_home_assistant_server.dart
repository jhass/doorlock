import 'dart:convert';
import 'dart:io';

/// Mock Home Assistant server for integration testing
class MockHomeAssistantServer {
  static HttpServer? _server;
  static const int port = 8123;
  
  static Future<void> start() async {
    if (_server != null) return;
    
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('🏠 Mock Home Assistant server started on http://localhost:$port');
    
    // Handle requests asynchronously without blocking
    _server!.listen(_handleRequest);
  }
  
  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('🏠 Mock Home Assistant server stopped');
  }
  
  static Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (method == 'OPTIONS') {
      request.response.statusCode = 200;
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
    final response = {
      'access_token': 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      'token_type': 'Bearer',
      'expires_in': 3600,
      'refresh_token': 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
    };
    
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }
}