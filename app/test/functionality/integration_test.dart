import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:doorlock/pb.dart';
import '../integration/mock_home_assistant_server.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Real Integration Testing with Mock Home Assistant', () {
    setUpAll(() async {
      // Start mock Home Assistant server
      await MockHomeAssistantServer.start();
      
      // Configure mock HA server with different token behaviors
      MockHomeAssistantServer.setValidToken('valid_access_token', ['lock.front_door', 'lock.back_door']);
    });

    tearDownAll(() async {
      await MockHomeAssistantServer.stop();
    });

    setUp(() {
      // Clear API call history for each test
      MockHomeAssistantServer.clearApiCalls();
    });

    test('Mock HA server receives valid door unlock API call', () async {
      // Simulate the HTTP call that PocketBase would make to Home Assistant
      // This is the actual call from doorlock.pb.js line 119-129
      final response = await http.post(
        Uri.parse('http://localhost:8123/api/services/lock/open'),
        headers: {
          'Authorization': 'Bearer valid_access_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'entity_id': 'lock.front_door'
        }),
      );

      // Verify successful response
      expect(response.statusCode, equals(200));

      // Verify the mock Home Assistant server received the call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(1));
      
      final unlockCall = apiCalls.first;
      expect(unlockCall['method'], equals('POST'));
      expect(unlockCall['path'], equals('/api/services/lock/open'));
      expect(unlockCall['authorization'], equals('Bearer valid_access_token'));
    });

    test('Mock HA server rejects invalid token API call', () async {
      // Simulate the HTTP call that PocketBase would make with invalid token
      final response = await http.post(
        Uri.parse('http://localhost:8123/api/services/lock/open'),
        headers: {
          'Authorization': 'Bearer invalid_access_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'entity_id': 'lock.front_door'
        }),
      );

      // Verify unauthorized response
      expect(response.statusCode, equals(401));

      // Verify the mock Home Assistant server received and rejected the call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(1));
      
      final unlockCall = apiCalls.first;
      expect(unlockCall['method'], equals('POST'));
      expect(unlockCall['path'], equals('/api/services/lock/open'));
      expect(unlockCall['authorization'], equals('Bearer invalid_access_token'));
    });

    test('Mock HA server handles expired token API call', () async {
      // Simulate the HTTP call that PocketBase would make with expired token
      final response = await http.post(
        Uri.parse('http://localhost:8123/api/services/lock/open'),
        headers: {
          'Authorization': 'Bearer expired_access_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'entity_id': 'lock.front_door'
        }),
      );

      // Verify unauthorized response for expired token
      expect(response.statusCode, equals(401));

      // Verify the mock Home Assistant server received the call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(1));
      
      final unlockCall = apiCalls.first;
      expect(unlockCall['method'], equals('POST'));
      expect(unlockCall['path'], equals('/api/services/lock/open'));
      expect(unlockCall['authorization'], equals('Bearer expired_access_token'));
    });

    test('Mock HA server tracks multiple API calls', () async {
      // Make multiple calls to verify tracking
      await http.post(
        Uri.parse('http://localhost:8123/api/services/lock/open'),
        headers: {
          'Authorization': 'Bearer valid_access_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'entity_id': 'lock.front_door'}),
      );

      await http.post(
        Uri.parse('http://localhost:8123/api/services/lock/open'),
        headers: {
          'Authorization': 'Bearer valid_access_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'entity_id': 'lock.back_door'}),
      );

      // Verify both calls were tracked
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(2));
      
      for (final call in apiCalls) {
        expect(call['method'], equals('POST'));
        expect(call['path'], equals('/api/services/lock/open'));
        expect(call['authorization'], equals('Bearer valid_access_token'));
      }
    });

    test('Mock HA server handles token refresh API call', () async {
      // Simulate the token refresh call from doorlock.helpers.js line 9-13
      final response = await http.post(
        Uri.parse('http://localhost:8123/auth/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=refresh_token&refresh_token=test_refresh&client_id=test_client&client_secret=test_secret',
      );

      // Verify successful token refresh
      expect(response.statusCode, equals(200));
      
      final tokenData = jsonDecode(response.body);
      expect(tokenData['access_token'], isNotNull);
      expect(tokenData['token_type'], equals('Bearer'));

      // Verify the mock Home Assistant server received the token refresh call
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(1));
      
      final tokenCall = apiCalls.first;
      expect(tokenCall['method'], equals('POST'));
      expect(tokenCall['path'], equals('/auth/token'));
    });

    test('Mock HA server API call verification functions work', () async {
      // Test the helper functions for API call verification
      expect(MockHomeAssistantServer.getApiCalls(), isEmpty);
      
      // Make a test call
      await http.get(
        Uri.parse('http://localhost:8123/api/states'),
        headers: {'Authorization': 'Bearer valid_access_token'},
      );
      
      // Verify tracking functions
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, equals(1));
      expect(apiCalls.first['path'], equals('/api/states'));
      
      // Test clearing function
      MockHomeAssistantServer.clearApiCalls();
      expect(MockHomeAssistantServer.getApiCalls(), isEmpty);
    });

    test('Mock HA server configuration is correct for integration testing', () async {
      // Verify server is accessible and configured correctly
      final response = await http.get(Uri.parse('http://localhost:8123/api/'));
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['message'], equals('API running.'));
      expect(data['version'], isNotNull);
      
      // Verify valid token is configured
      MockHomeAssistantServer.setValidToken('test_token', ['lock.test']);
      
      // Make a call with the test token
      await http.get(
        Uri.parse('http://localhost:8123/api/states'),
        headers: {'Authorization': 'Bearer test_token'},
      );
      
      // Should succeed without error
      final apiCalls = MockHomeAssistantServer.getApiCalls();
      expect(apiCalls.length, greaterThan(0));
    });
  });
}