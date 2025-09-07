import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;

/// Mock PocketBase client for testing
class MockPocketBase extends PocketBase {
  final Map<String, List<Map<String, dynamic>>> _collections = {};
  final MockAuthStore _authStore = MockAuthStore();
  bool _shouldFailAuth = false;
  bool _shouldFailRequests = false;
  String? _customErrorMessage;

  MockPocketBase() : super('http://mock-pocketbase:8090');

  @override
  AuthStore get authStore => _authStore;

  // Test configuration methods
  void setShouldFailAuth(bool fail) => _shouldFailAuth = fail;
  void setShouldFailRequests(bool fail) => _shouldFailRequests = fail;
  void setCustomErrorMessage(String? message) => _customErrorMessage = message;

  void seedCollection(String name, List<Map<String, dynamic>> data) {
    _collections[name] = List.from(data);
  }

  void clearAllData() {
    _collections.clear();
    _authStore.clear();
  }

  // Make collections accessible for testing
  Map<String, List<Map<String, dynamic>>> get collections => _collections;

  @override
  RecordService collection(String collectionName) {
    return MockRecordService(collectionName, this);
  }

  @override
  Future<T> send<T extends dynamic>(
    String path, {
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    dynamic body,
    List<http.MultipartFile>? files,
  }) async {
    if (_shouldFailRequests) {
      throw ClientException(
        statusCode: 500,
        response: {'message': _customErrorMessage ?? 'Mock server error'},
      );
    }

    // Handle custom doorlock endpoints
    if (path == '/doorlock/homeassistant' && method == 'POST') {
      final url = body?['url'] as String?;
      final callback = body?['frontend_callback'] as String?;
      
      if (url == null || callback == null) {
        throw ClientException(
          statusCode: 400,
          response: {'message': 'Missing required fields'},
        );
      }

      // Simulate adding a new home assistant
      final assistants = _collections['doorlock_homeassistants'] ?? [];
      final newAssistant = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'url': url,
        'frontend_callback': callback,
        'created': DateTime.now().toIso8601String(),
        'updated': DateTime.now().toIso8601String(),
      };
      assistants.add(newAssistant);
      _collections['doorlock_homeassistants'] = assistants;

      // Return auth URL for OAuth flow
      return {
        'auth_url': '$url/auth/external/callback?state=test&code=test123'
      } as T;
    }

    return super.send<T>(
      path, 
      method: method, 
      headers: headers ?? {},
      query: query ?? {},
      body: body, 
      files: files ?? [],
    );
  }
}

class MockRecordService extends RecordService {
  final String _collectionName;
  final MockPocketBase _mockPb;

  MockRecordService(this._collectionName, this._mockPb) : super(_mockPb, _collectionName);

  @override
  Future<RecordAuth> authWithPassword(
    String usernameOrEmail,
    String password, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    if (_mockPb._shouldFailAuth) {
      throw ClientException(
        statusCode: 401,
        response: {'message': _mockPb._customErrorMessage ?? 'Invalid credentials'},
      );
    }

    // Simulate successful authentication
    final token = 'mock-jwt-token-${DateTime.now().millisecondsSinceEpoch}';
    final user = RecordModel({
      'id': 'user123',
      'email': usernameOrEmail,
      'username': usernameOrEmail,
      'created': DateTime.now().toIso8601String(),
      'updated': DateTime.now().toIso8601String(),
    });

    _mockPb._authStore.save(token, user);
    return RecordAuth(token: token, record: user);
  }

  @override
  Future<List<RecordModel>> getFullList({
    int batch = 500,
    String fields = '',
    String? expand,
    String? filter,
    String sort = '',
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    if (_mockPb._shouldFailRequests) {
      throw ClientException(
        statusCode: 500,
        response: {'message': _mockPb._customErrorMessage ?? 'Failed to fetch data'},
      );
    }

    final data = _mockPb._collections[_collectionName] ?? [];
    return data.map((item) => RecordModel(item)).toList();
  }
}

class MockAuthStore extends AuthStore {
  String? _token;
  RecordModel? _model;

  @override
  String get token => _token ?? '';

  @override
  RecordModel? get model => _model;

  @override
  bool get isValid => _token != null && _token!.isNotEmpty;

  @override
  void save(String newToken, RecordModel? newModel) {
    _token = newToken;
    _model = newModel;
  }

  @override
  void clear() {
    _token = null;
    _model = null;
  }
}