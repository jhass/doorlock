import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/pb.dart';
import 'package:doorlock/session_storage.dart';

import '../mocks/mock_pocketbase.dart';
import '../mocks/mock_home_assistant_server.dart';
import '../mocks/mock_url_launcher.dart';

/// Test data and environment setup utilities
class TestEnvironment {
  static MockPocketBase? _mockPb;
  static MockHomeAssistantServer? _mockHaServer;
  static bool _isSetup = false;

  /// Get the mock PocketBase instance
  static MockPocketBase get mockPb => _mockPb!;

  /// Get the mock Home Assistant server
  static MockHomeAssistantServer get mockHaServer => _mockHaServer!;

  /// Setup the complete test environment
  static Future<void> setup() async {
    if (_isSetup) return;

    // Setup mock PocketBase
    _mockPb = MockPocketBase();
    
    // Setup mock Home Assistant server
    _mockHaServer = MockHomeAssistantServer();
    await _mockHaServer!.start();
    
    // Setup mock URL launcher
    setupMockUrlLauncher();
    
    _isSetup = true;
  }

  /// Clean up the test environment
  static Future<void> tearDown() async {
    if (!_isSetup) return;

    await _mockHaServer?.stop();
    _mockPb?.clearAllData();
    MockUrlLauncher.clearHistory();
    
    _isSetup = false;
  }

  /// Reset all test data without tearing down services
  static void resetData() {
    _mockPb?.clearAllData();
    _mockHaServer?.clearData();
    MockUrlLauncher.clearHistory();
  }

  /// Seed the test environment with realistic data
  static void seedTestData() {
    seedUserData();
    seedHomeAssistantData();
    seedLockData();
  }

  /// Seed user authentication data
  static void seedUserData() {
    // Mock PB handles user creation during auth, but we can pre-configure auth behavior
    _mockPb?.setShouldFailAuth(false);
    _mockPb?.setShouldFailRequests(false);
  }

  /// Seed Home Assistant instance data
  static void seedHomeAssistantData() {
    final testAssistants = [
      {
        'id': 'ha1',
        'url': _mockHaServer!.baseUrl,
        'frontend_callback': 'http://localhost:3000/callback',
        'name': 'Main Home Assistant',
        'created': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'updated': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'ha2', 
        'url': 'https://homeassistant.local:8123',
        'frontend_callback': 'http://localhost:3000/callback',
        'name': 'Local Home Assistant',
        'created': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'updated': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
      },
      {
        'id': 'ha3',
        'url': 'https://my-ha.duckdns.org',
        'frontend_callback': 'http://localhost:3000/callback', 
        'name': 'Remote Home Assistant',
        'created': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'updated': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
    ];

    _mockPb?.seedCollection('doorlock_homeassistants', testAssistants);
  }

  /// Seed lock entity data in the mock Home Assistant server
  static void seedLockData() {
    _mockHaServer?.addLockEntity('lock.front_door', isLocked: true);
    _mockHaServer?.addLockEntity('lock.back_door', isLocked: true);
    _mockHaServer?.addLockEntity('lock.garage_door', isLocked: false);
    _mockHaServer?.addLockEntity('lock.side_gate', isLocked: true);
    _mockHaServer?.addLockEntity('lock.office_door', isLocked: false);

    // Add valid tokens for testing
    _mockHaServer?.addToken('valid-token-123', 'Test doorlock app');
    _mockHaServer?.addToken('grant-token-456', 'Grant access token');
  }

  /// Create a test scenario with authentication failure
  static void setupAuthFailureScenario() {
    resetData();
    _mockPb?.setShouldFailAuth(true);
    _mockPb?.setCustomErrorMessage('Invalid username or password');
  }

  /// Create a test scenario with server errors
  static void setupServerErrorScenario() {
    resetData();
    seedTestData();
    _mockPb?.setShouldFailRequests(true);
    _mockPb?.setCustomErrorMessage('Server temporarily unavailable');
    _mockHaServer?.setShouldFailRequests(true);
  }

  /// Create a test scenario with Home Assistant authentication errors
  static void setupHomeAssistantAuthErrorScenario() {
    resetData();
    seedTestData();
    _mockHaServer?.setShouldFailAuth(true);
  }

  /// Create a test scenario with empty data
  static void setupEmptyDataScenario() {
    resetData();
    seedUserData(); // Keep user auth working but no other data
  }

  /// Authenticate a test user
  static Future<void> authenticateTestUser() async {
    await _mockPb?.collection('doorlock_users').authWithPassword('testuser@example.com', 'password123');
  }

  /// Helper to create a MaterialApp with proper test setup
  static MaterialApp createTestApp(Widget home) {
    return MaterialApp(
      title: 'Doorlock Test App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: home,
    );
  }
}

/// Test scenario configurations
class TestScenarios {
  /// Standard test scenario with full data
  static Future<void> standardScenario() async {
    await TestEnvironment.setup();
    TestEnvironment.seedTestData();
    await TestEnvironment.authenticateTestUser();
  }

  /// Authentication failure scenario
  static Future<void> authFailureScenario() async {
    await TestEnvironment.setup();
    TestEnvironment.setupAuthFailureScenario();
  }

  /// Server error scenario  
  static Future<void> serverErrorScenario() async {
    await TestEnvironment.setup();
    TestEnvironment.setupServerErrorScenario();
  }

  /// Empty data scenario
  static Future<void> emptyDataScenario() async {
    await TestEnvironment.setup();
    TestEnvironment.setupEmptyDataScenario();
    await TestEnvironment.authenticateTestUser();
  }

  /// Home Assistant connection error scenario
  static Future<void> homeAssistantErrorScenario() async {
    await TestEnvironment.setup();
    TestEnvironment.setupHomeAssistantAuthErrorScenario();
    await TestEnvironment.authenticateTestUser();
  }
}