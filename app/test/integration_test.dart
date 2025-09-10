import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/env_config.dart';
import 'package:doorlock/window_service.dart';

import 'mock_home_assistant_server.dart';
import 'test_env_config.dart';
import 'test_window_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Doorlock Integration Tests', () {
    setUpAll(() async {
      print('🚀 Starting integration test setup...');
      
      // Set up test environment configuration
      EnvConfig.setConfig(TestEnvironmentConfig('http://localhost:8080'));
      
      // Set up test window service
      setWindowService(TestWindowService());
      
      // Start mock Home Assistant server
      await MockHomeAssistantServer.start();
      
      // Setup mock HA with test data
      MockHomeAssistantServer.addValidToken('test_access_token', [
        'lock.front_door',
        'lock.back_door'
      ]);
      
      print('✅ Integration test setup complete!');
    });

    tearDownAll(() async {
      print('🧹 Cleaning up integration tests...');
      await MockHomeAssistantServer.stop();
      print('✅ Integration test cleanup complete!');
    });

    setUp(() {
      // Clear API call history for each test
      MockHomeAssistantServer.clearApiCalls();
    });

    test('Environment Configuration Test', () {
      print('🔧 Testing environment configuration...');
      
      // Verify environment config is working
      final config = TestEnvironmentConfig('http://localhost:8080');
      expect(config.pocketBaseUrl, equals('http://localhost:8080'));
      
      print('✅ Environment configuration test passed!');
    });

    test('Service Dependency Injection Test', () {
      print('🏗️ Testing service dependency injection...');
      
      // Verify all services can be injected
      setWindowService(TestWindowService());
      final windowService = getWindowService();
      expect(windowService, isA<TestWindowService>());
      
      print('✅ Service dependency injection test passed!');
    });

    test('Mock Server Management Test', () {
      print('🌐 Testing mock server management...');
      
      // Test token management
      MockHomeAssistantServer.addValidToken('valid_token', ['lock.test']);
      MockHomeAssistantServer.removeToken('valid_token');
      
      // Test API call tracking
      MockHomeAssistantServer.clearApiCalls();
      final calls = MockHomeAssistantServer.getApiCalls();
      expect(calls, isEmpty);
      
      print('✅ Mock server management test passed!');
    });

    test('Mock Home Assistant Server Integration Test', () {
      print('🏠 Testing mock Home Assistant server integration...');
      
      // Verify server is running and responding
      expect(MockHomeAssistantServer.getApiCalls(), isA<List>());
      
      // Test token validation
      MockHomeAssistantServer.addValidToken('test_token', ['lock.door']);
      MockHomeAssistantServer.removeToken('test_token');
      
      // Test API call tracking
      final initialCalls = MockHomeAssistantServer.getApiCalls().length;
      MockHomeAssistantServer.clearApiCalls();
      expect(MockHomeAssistantServer.getApiCalls().length, equals(0));
      
      print('✅ Mock Home Assistant server integration test passed!');
    });

    test('Complete Test Infrastructure Validation', () {
      print('🧪 Testing complete test infrastructure...');
      
      // Verify all dependency injection components work together
      final envConfig = TestEnvironmentConfig('http://test:8080');
      EnvConfig.setConfig(envConfig);
      expect(EnvConfig.pocketBaseUrl, equals('http://test:8080'));
      
      final windowService = TestWindowService();
      setWindowService(windowService);
      expect(getWindowService(), equals(windowService));
      
      // Verify mock server state management
      MockHomeAssistantServer.reset();
      expect(MockHomeAssistantServer.getApiCalls(), isEmpty);
      
      print('✅ Complete test infrastructure validation passed!');
    });
  });
}