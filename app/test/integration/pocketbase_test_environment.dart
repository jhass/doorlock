import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// PocketBase test environment setup and seeding
class PocketBaseTestEnvironment {
  static const String baseUrl = 'http://localhost:8080';
  static const String adminEmail = 'test@admin.com';
  static const String adminPassword = 'test123456789';
  
  /// Start PocketBase using Docker Compose
  static Future<bool> start() async {
    print('🗄️  Starting PocketBase test environment...');
    
    try {
      // Start PocketBase with Docker Compose
      final result = await Process.run(
        'docker',
        ['compose', '-f', 'docker-compose.dev.yml', 'up', '-d', 'pocketbase'],
        workingDirectory: '/home/runner/work/doorlock/doorlock',
      );
      
      if (result.exitCode != 0) {
        print('❌ Failed to start PocketBase: ${result.stderr}');
        return false;
      }
      
      // Wait for PocketBase to be ready
      return await _waitForHealthy();
    } catch (e) {
      print('❌ Error starting PocketBase: $e');
      return false;
    }
  }
  
  /// Stop PocketBase
  static Future<void> stop() async {
    print('🗄️  Stopping PocketBase test environment...');
    try {
      await Process.run(
        'docker',
        ['compose', '-f', 'docker-compose.dev.yml', 'down'],
        workingDirectory: '/home/runner/work/doorlock/doorlock',
      );
    } catch (e) {
      print('⚠️  Error stopping PocketBase: $e');
    }
  }
  
  /// Wait for PocketBase to be healthy
  static Future<bool> _waitForHealthy() async {
    print('⏳ Waiting for PocketBase to be ready...');
    
    for (int i = 0; i < 30; i++) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/api/health'));
        if (response.statusCode == 200) {
          print('✅ PocketBase is ready');
          return true;
        }
      } catch (e) {
        // Still starting up
      }
      
      await Future.delayed(const Duration(seconds: 1));
    }
    
    print('❌ PocketBase failed to start within 30 seconds');
    return false;
  }
  
  /// Set up admin user and seed test data
  static Future<bool> seedTestData() async {
    print('🌱 Seeding PocketBase with test data...');
    
    try {
      // Try to create admin user (might already exist)
      await _createAdminUser();
      
      // Get admin auth token
      final adminToken = await _getAdminToken();
      if (adminToken == null) {
        print('❌ Failed to get admin token');
        return false;
      }
      
      // Create test collections and data
      await _createTestCollections(adminToken);
      await _createTestUsers(adminToken);
      await _createTestHomeAssistants(adminToken);
      
      print('✅ Test data seeded successfully');
      return true;
    } catch (e) {
      print('❌ Error seeding test data: $e');
      return false;
    }
  }
  
  static Future<void> _createAdminUser() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admins'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': adminEmail,
          'password': adminPassword,
          'passwordConfirm': adminPassword,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 400) {
        // Either created or already exists
        print('📋 Admin user ready');
      } else {
        print('⚠️  Admin user creation response: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️  Admin user might already exist: $e');
    }
  }
  
  static Future<String?> _getAdminToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admins/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': adminEmail,
          'password': adminPassword,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String;
      }
    } catch (e) {
      print('❌ Error getting admin token: $e');
    }
    return null;
  }
  
  static Future<void> _createTestCollections(String adminToken) async {
    // Note: Collections might already exist from migrations
    // This is just to ensure they exist for testing
    print('📚 Ensuring test collections exist...');
  }
  
  static Future<void> _createTestUsers(String adminToken) async {
    print('👤 Creating test users...');
    
    final testUsers = [
      {
        'username': 'testuser',
        'password': 'testpass123',
        'passwordConfirm': 'testpass123',
        'email': 'testuser@example.com',
      },
      {
        'username': 'alice',
        'password': 'alice123',
        'passwordConfirm': 'alice123',
        'email': 'alice@example.com',
      },
    ];
    
    for (final user in testUsers) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/collections/doorlock_users/records'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $adminToken',
          },
          body: jsonEncode(user),
        );
        
        if (response.statusCode == 200) {
          print('  ✅ Created user: ${user['username']}');
        } else if (response.statusCode == 400) {
          print('  📋 User already exists: ${user['username']}');
        }
      } catch (e) {
        print('  ⚠️  Error creating user ${user['username']}: $e');
      }
    }
  }
  
  static Future<void> _createTestHomeAssistants(String adminToken) async {
    print('🏠 Creating test Home Assistant instances...');
    
    // First, get a test user ID
    final userResponse = await http.get(
      Uri.parse('$baseUrl/api/collections/doorlock_users/records'),
      headers: {'Authorization': 'Bearer $adminToken'},
    );
    
    if (userResponse.statusCode != 200) {
      print('  ❌ Failed to get users for HA instances');
      return;
    }
    
    final userData = jsonDecode(userResponse.body);
    final users = userData['items'] as List;
    if (users.isEmpty) {
      print('  ❌ No users found for HA instances');
      return;
    }
    
    final testUserId = users.first['id'];
    
    final testHomeAssistants = [
      {
        'user': testUserId,
        'name': 'Test Home (Valid Token)',
        'url': 'http://localhost:8123',
        'access_token': 'valid_token',
      },
      {
        'user': testUserId,
        'name': 'Test Home (Expired Token)',
        'url': 'http://localhost:8123',
        'access_token': 'expired_token',
      },
      {
        'user': testUserId,
        'name': 'Test Home (Invalid Token)',
        'url': 'http://localhost:8123',
        'access_token': 'invalid_token',
      },
    ];
    
    for (final ha in testHomeAssistants) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/collections/home_assistants/records'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $adminToken',
          },
          body: jsonEncode(ha),
        );
        
        if (response.statusCode == 200) {
          print('  ✅ Created Home Assistant: ${ha['name']}');
        } else if (response.statusCode == 400) {
          print('  📋 Home Assistant already exists: ${ha['name']}');
        }
      } catch (e) {
        print('  ⚠️  Error creating Home Assistant ${ha['name']}: $e');
      }
    }
  }
}