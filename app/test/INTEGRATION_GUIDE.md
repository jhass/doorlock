# Integration Testing Guide

## Test Suite Architecture

### Widget Tests (Automated)
- **Location**: `test/functionality/`
- **Purpose**: Component-level testing with real app code
- **Run**: `make widget-test`

Tests:
- `authentication_test.dart` - Sign-in/sign-out flows
- `home_assistant_management_test.dart` - HA connection workflows  
- `qr_code_flow_test.dart` - QR scanning and door opening

### Integration Environment (Manual)
- **Purpose**: End-to-end testing with real PocketBase backend
- **Setup**: `make setup-integration-env`

## Running Integration Tests

### Automated Widget Tests
```bash
make widget-test
```

### Manual Integration Testing
```bash
# 1. Set up environment
make setup-integration-env

# 2. Start the app
cd app && flutter run -d web-server --web-port 8090

# 3. Test in browser
# Navigate to: http://localhost:8090
# Sign in with: testuser / testpass123
```

## Test Data

The integration environment includes:
- **PocketBase**: http://localhost:8080 with admin panel
- **Test Users**: `testuser/testpass123`, `alice/alice123`
- **Mock Home Assistants**: Pre-configured test instances
- **Seeded Data**: Realistic test scenarios

## Integration Test Infrastructure

### Mock Home Assistant Server
- **File**: `test/integration/mock_home_assistant_server.dart`
- **Purpose**: Simulates Home Assistant API responses
- **Endpoints**: `/api/states`, `/api/services/lock/unlock`, OAuth flows

### PocketBase Environment
- **File**: `test/integration/pocketbase_test_environment.dart`
- **Purpose**: Sets up real PocketBase with test data
- **Features**: Docker orchestration, data seeding, user management

### Test Orchestration
- **Script**: `scripts/setup_integration_environment.sh`
- **Purpose**: One-command test environment setup
- **Includes**: Database seeding, service startup, test data creation

## Platform Considerations

The app uses web-specific libraries (`dart:js_interop`) that aren't available in Flutter test environments. This is why we use:

1. **Widget tests** for automated testing
2. **Manual integration testing** with real services
3. **Mock infrastructure** for future automated e2e tests

This approach provides comprehensive coverage while working within Flutter's platform constraints.