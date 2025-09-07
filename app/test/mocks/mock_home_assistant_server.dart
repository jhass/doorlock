import 'dart:io';
import 'dart:convert';

/// Mock Home Assistant server for testing doorlock functionality
class MockHomeAssistantServer {
  late HttpServer _server;
  int _port = 8123;
  bool _isRunning = false;
  
  // Mock data storage
  final Map<String, dynamic> _entities = {};
  final Map<String, String> _tokens = {};
  bool _shouldFailAuth = false;
  bool _shouldFailRequests = false;

  int get port => _port;
  bool get isRunning => _isRunning;
  String get baseUrl => 'http://localhost:$_port';

  /// Start the mock server
  Future<void> start({int? port}) async {
    if (_isRunning) return;
    
    _port = port ?? await _findAvailablePort();
    _server = await HttpServer.bind('localhost', _port);
    _isRunning = true;
    
    _server.listen(_handleRequest);
    
    // Seed with default doorlock entities
    _seedDefaultEntities();
  }

  /// Stop the mock server
  Future<void> stop() async {
    if (!_isRunning) return;
    
    await _server.close();
    _isRunning = false;
  }

  /// Configure test scenarios
  void setShouldFailAuth(bool fail) => _shouldFailAuth = fail;
  void setShouldFailRequests(bool fail) => _shouldFailRequests = fail;
  
  void addLockEntity(String entityId, {bool isLocked = true}) {
    _entities[entityId] = {
      'entity_id': entityId,
      'state': isLocked ? 'locked' : 'unlocked',
      'attributes': {
        'friendly_name': 'Test Lock ${entityId.split('.').last}',
        'supported_features': 1,
      },
      'last_changed': DateTime.now().toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  void addToken(String token, String description) {
    _tokens[token] = description;
  }

  void clearData() {
    _entities.clear();
    _tokens.clear();
  }

  void _seedDefaultEntities() {
    addLockEntity('lock.front_door', isLocked: true);
    addLockEntity('lock.back_door', isLocked: true);
    addLockEntity('lock.garage_door', isLocked: false);
    
    addToken('test-token-123', 'Test doorlock app');
    addToken('valid-ha-token', 'Valid test token');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    
    try {
      Map<String, dynamic>? response;
      int statusCode = 200;

      if (_shouldFailRequests) {
        statusCode = 500;
        response = {'message': 'Mock server error'};
      } else if (path == '/auth/token' && method == 'POST') {
        response = _handleTokenAuth(request);
      } else if (path.startsWith('/api/states/') && method == 'GET') {
        response = _handleGetState(request);
      } else if (path.startsWith('/api/services/') && method == 'POST') {
        response = await _handleServiceCall(request);
      } else if (path == '/api/states' && method == 'GET') {
        response = _handleGetAllStates(request);
      } else if (path == '/auth/external/callback' && method == 'GET') {
        response = _handleOAuthCallback(request);
      } else {
        statusCode = 404;
        response = {'message': 'Not found'};
      }

      request.response.statusCode = statusCode;
      request.response.headers.set('Content-Type', 'application/json');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
      request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      
      if (response != null) {
        request.response.write(jsonEncode(response));
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'message': 'Internal server error: $e'}));
    } finally {
      await request.response.close();
    }
  }

  Map<String, dynamic> _handleTokenAuth(HttpRequest request) {
    if (_shouldFailAuth) {
      throw HttpException('Authentication failed');
    }
    
    return {
      'access_token': 'mock-ha-access-token-${DateTime.now().millisecondsSinceEpoch}',
      'token_type': 'Bearer',
      'expires_in': 3600,
    };
  }

  Map<String, dynamic>? _handleGetState(HttpRequest request) {
    final entityId = request.uri.path.split('/').last;
    final auth = request.headers.value('Authorization');
    
    if (auth == null || !auth.startsWith('Bearer ')) {
      throw HttpException('Unauthorized');
    }
    
    return _entities[entityId];
  }

  Future<Map<String, dynamic>> _handleServiceCall(HttpRequest request) async {
    final pathParts = request.uri.path.split('/');
    final domain = pathParts[3];
    final service = pathParts[4];
    
    final auth = request.headers.value('Authorization');
    if (auth == null || !auth.startsWith('Bearer ')) {
      throw HttpException('Unauthorized');
    }

    // Read request body
    final bodyString = await utf8.decoder.bind(request).join();
    final body = bodyString.isNotEmpty ? jsonDecode(bodyString) : <String, dynamic>{};
    
    if (domain == 'lock' && (service == 'unlock' || service == 'lock')) {
      final entityId = body['entity_id'] as String?;
      if (entityId != null && _entities.containsKey(entityId)) {
        _entities[entityId]!['state'] = service == 'lock' ? 'locked' : 'unlocked';
        _entities[entityId]!['last_changed'] = DateTime.now().toIso8601String();
        _entities[entityId]!['last_updated'] = DateTime.now().toIso8601String();
        
        return {'states': [_entities[entityId]!]};
      }
    }
    
    return {'states': []};
  }

  Map<String, dynamic> _handleGetAllStates(HttpRequest request) {
    final auth = request.headers.value('Authorization');
    if (auth == null || !auth.startsWith('Bearer ')) {
      throw HttpException('Unauthorized');
    }
    
    return {
      'states': _entities.values.toList(),
    };
  }

  Map<String, dynamic> _handleOAuthCallback(HttpRequest request) {
    final state = request.uri.queryParameters['state'];
    final code = request.uri.queryParameters['code'];
    
    if (state == null || code == null) {
      throw HttpException('Missing required parameters');
    }
    
    return {
      'success': true,
      'message': 'OAuth callback successful',
      'state': state,
      'code': code,
    };
  }

  Future<int> _findAvailablePort() async {
    for (int port = 8123; port < 9000; port++) {
      try {
        final server = await HttpServer.bind('localhost', port);
        await server.close();
        return port;
      } catch (e) {
        // Port is in use, try next one
        continue;
      }
    }
    throw Exception('No available ports found');
  }
}