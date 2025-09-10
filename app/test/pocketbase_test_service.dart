import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to setup and manage PocketBase for integration testing
class PocketBaseTestService {
  static const String _pocketBaseUrl = 'http://localhost:8080';
  static const String _adminEmail = 'admin@test.com';
  static const String _adminPassword = 'testpassword123';
  
  static const String _testUsername = 'testuser';
  static const String _testPassword = 'testpass123';
  
  static String? _adminToken;

  /// Setup PocketBase with test data
  static Future<void> setup() async {
    print('Setting up PocketBase for integration testing...');
    
    // Wait for PocketBase to be ready
    await _waitForPocketBase();
    
    // Create admin user if it doesn't exist
    await _setupAdmin();
    
    // Create test user
    await _createTestUser();
    
    // Create test home assistant configuration
    await _createTestHomeAssistant();
    
    print('PocketBase setup complete!');
  }

  /// Wait for PocketBase to be ready
  static Future<void> _waitForPocketBase() async {
    print('Waiting for PocketBase to be ready...');
    
    for (int i = 0; i < 30; i++) {
      try {
        final response = await http.get(Uri.parse('$_pocketBaseUrl/api/health'));
        if (response.statusCode == 200) {
          print('PocketBase is ready!');
          return;
        }
      } catch (e) {
        // PocketBase not ready yet
      }
      
      await Future.delayed(const Duration(seconds: 1));
    }
    
    throw Exception('PocketBase did not start within 30 seconds');
  }

  /// Setup admin user
  static Future<void> _setupAdmin() async {
    print('Setting up authentication for PocketBase...');
    
    // Skip admin setup in dev mode - try creating a test user directly first
    try {
      // Try creating a test user in the doorlock_users collection
      final createUserResponse = await http.post(
        Uri.parse('$_pocketBaseUrl/api/collections/doorlock_users/records'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'testuser@example.com',
          'password': 'testpass123',
          'passwordConfirm': 'testpass123',
        }),
      );

      if (createUserResponse.statusCode == 200 || createUserResponse.statusCode == 201) {
        print('Test user created successfully');
        
        // Authenticate as the test user
        final authResponse = await http.post(
          Uri.parse('$_pocketBaseUrl/api/collections/doorlock_users/auth-with-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identity': 'testuser@example.com',
            'password': 'testpass123',
          }),
        );

        if (authResponse.statusCode == 200) {
          final authData = jsonDecode(authResponse.body);
          _adminToken = authData['token'];
          print('Test user authenticated successfully');
          return;
        }
      }
    } catch (e) {
      print('User creation approach failed: $e');
    }

    // Fallback to admin approach
    try {
      // Try to authenticate as admin first
      final authResponse = await http.post(
        Uri.parse('$_pocketBaseUrl/api/admins/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': _adminEmail,
          'password': _adminPassword,
        }),
      );

      if (authResponse.statusCode == 200) {
        final authData = jsonDecode(authResponse.body);
        _adminToken = authData['token'];
        print('Admin authentication successful');
        return;
      }
    } catch (e) {
      // Admin doesn't exist, create it
    }

    // Create admin user as last resort
    print('Creating admin user...');
    final createResponse = await http.post(
      Uri.parse('$_pocketBaseUrl/api/admins'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _adminEmail,
        'password': _adminPassword,
        'passwordConfirm': _adminPassword,
      }),
    );

    if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
      // Authenticate as admin
      final authResponse = await http.post(
        Uri.parse('$_pocketBaseUrl/api/admins/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': _adminEmail,
          'password': _adminPassword,
        }),
      );

      if (authResponse.statusCode == 200) {
        final authData = jsonDecode(authResponse.body);
        _adminToken = authData['token'];
        print('Admin user created and authenticated');
        return;
      }
    }

    throw Exception('Failed to set up PocketBase authentication');
  }

  /// Create doorlock_users collection and test user
  static Future<void> _createTestUser() async {
    if (_adminToken == null) {
      throw Exception('Admin token not available');
    }

    // Check if collection exists
    try {
      final collectionResponse = await http.get(
        Uri.parse('$_pocketBaseUrl/api/collections/doorlock_users'),
        headers: {'Authorization': 'Bearer $_adminToken'},
      );

      if (collectionResponse.statusCode != 200) {
        await _createUsersCollection();
      }
    } catch (e) {
      await _createUsersCollection();
    }

    // Create test user
    print('Creating test user...');
    final userResponse = await http.post(
      Uri.parse('$_pocketBaseUrl/api/collections/doorlock_users/records'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': _testUsername,
        'password': _testPassword,
        'passwordConfirm': _testPassword,
        'email': 'test@example.com',
      }),
    );

    if (userResponse.statusCode == 200) {
      print('Test user created successfully');
    } else {
      print('Test user might already exist or creation failed: ${userResponse.body}');
    }
  }

  /// Create doorlock_users collection
  static Future<void> _createUsersCollection() async {
    print('Creating doorlock_users collection...');
    
    final collectionData = {
      'name': 'doorlock_users',
      'type': 'auth',
      'schema': [
        {
          'name': 'username',
          'type': 'text',
          'required': true,
          'options': {'min': 3, 'max': 50}
        },
        {
          'name': 'email',
          'type': 'email',
          'required': true,
          'options': {}
        }
      ],
      'listRule': '@request.auth.id != ""',
      'viewRule': '@request.auth.id != ""',
      'createRule': '',
      'updateRule': '@request.auth.id = id',
      'deleteRule': '@request.auth.id = id',
    };

    final response = await http.post(
      Uri.parse('$_pocketBaseUrl/api/collections'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(collectionData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create doorlock_users collection: ${response.body}');
    }

    print('doorlock_users collection created');
  }

  /// Create test Home Assistant configuration
  static Future<void> _createTestHomeAssistant() async {
    if (_adminToken == null) {
      throw Exception('Admin token not available');
    }

    // Check if collection exists
    try {
      final collectionResponse = await http.get(
        Uri.parse('$_pocketBaseUrl/api/collections/doorlock_homeassistants'),
        headers: {'Authorization': 'Bearer $_adminToken'},
      );

      if (collectionResponse.statusCode != 200) {
        await _createHomeAssistantsCollection();
      }
    } catch (e) {
      await _createHomeAssistantsCollection();
    }

    print('Test Home Assistant configuration ready');
  }

  /// Create doorlock_homeassistants collection
  static Future<void> _createHomeAssistantsCollection() async {
    print('Creating doorlock_homeassistants collection...');
    
    final collectionData = {
      'name': 'doorlock_homeassistants',
      'type': 'base',
      'schema': [
        {
          'name': 'user',
          'type': 'relation',
          'required': true,
          'options': {
            'collectionId': 'doorlock_users',
            'cascadeDelete': true,
            'minSelect': null,
            'maxSelect': 1,
            'displayFields': null
          }
        },
        {
          'name': 'url',
          'type': 'url',
          'required': true,
          'options': {}
        },
        {
          'name': 'name',
          'type': 'text',
          'required': false,
          'options': {}
        },
        {
          'name': 'access_token',
          'type': 'text',
          'required': false,
          'options': {}
        },
        {
          'name': 'refresh_token',
          'type': 'text',
          'required': false,
          'options': {}
        }
      ],
      'listRule': 'user.id = @request.auth.id',
      'viewRule': 'user.id = @request.auth.id',
      'createRule': 'user.id = @request.auth.id',
      'updateRule': 'user.id = @request.auth.id',
      'deleteRule': 'user.id = @request.auth.id',
    };

    final response = await http.post(
      Uri.parse('$_pocketBaseUrl/api/collections'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(collectionData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create doorlock_homeassistants collection: ${response.body}');
    }

    print('doorlock_homeassistants collection created');
  }

  /// Get test user credentials
  static Map<String, String> getTestUserCredentials() {
    return {
      'username': _testUsername,
      'password': _testPassword,
    };
  }

  /// Clean up test data
  static Future<void> cleanup() async {
    print('Cleaning up test data...');
    // The collections and data will be cleaned up when PocketBase container stops
  }
}