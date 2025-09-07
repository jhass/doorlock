# Integration Test Suite

This directory contains comprehensive integration tests that boot the complete Doorlock application (backend + frontend) and walk through all screens and dialogs.

## Overview

The integration test suite provides:
- **End-to-end testing** of the complete application flow
- **UI testing** of all screens, dialogs, and modals
- **Form validation** testing
- **Error handling** testing
- **Navigation** consistency testing
- **Loading states** testing

## Test Files

### 1. `app_flow_test.dart`
Main application flow walkthrough that tests:
- Sign in flow
- Home Assistants page functionality
- Add Home Assistant workflow
- Navigation consistency
- Logout flow
- Grant flow structure (UI components)

### 2. `complete_ui_walkthrough_test.dart`
Comprehensive UI testing including:
- Detailed form validation testing
- Error handling and user feedback
- Loading states and responsiveness
- Authentication edge cases
- Network error simulation

### 3. `dialogs_and_grant_flow_test.dart`
Specialized testing for:
- Modal dialogs and bottom sheets
- Confirmation dialogs
- QR code functionality
- Grant flow UI components
- Widget interaction testing
- App state management
- Performance testing

## Running Tests

### Prerequisites
1. Ensure Docker and Docker Compose are installed
2. PocketBase backend should be running (tests will start it if needed)

### Quick Start
```bash
# Run all integration tests
make integration-test

# Run specific test suites
make integration-test-ui        # UI walkthrough tests
make integration-test-dialogs   # Dialogs and grant flow tests

# Manual execution
cd app
../scripts/run-integration-tests.sh --all
```

### Test Options
```bash
# Run all tests
../scripts/run-integration-tests.sh --all

# Run specific test categories
../scripts/run-integration-tests.sh --ui
../scripts/run-integration-tests.sh --dialogs
../scripts/run-integration-tests.sh --flow

# Run specific test file
../scripts/run-integration-tests.sh integration_test/app_flow_test.dart
```

## Test Environment

### Automatic Setup
The test runner automatically:
1. **Starts PocketBase** backend if not running
2. **Creates test data** (test user: `testuser` / `testpass123`)
3. **Waits for services** to be ready
4. **Cleans up** after tests complete

### Manual Setup
To manually set up the test environment:
```bash
# Start backend with test data
./scripts/start-integration-test.sh

# In another terminal, run tests
cd app
flutter test integration_test/
```

## Test Coverage

### Screens Tested
- **Sign In Page**: Form validation, authentication, error handling
- **Home Assistants Page**: List view, navigation, app bar actions
- **Add Home Assistant Page**: Form validation, URL validation, error states
- **Navigation**: Consistent navigation between all screens

### User Flows Tested
1. **Authentication Flow**:
   - Empty form submission → validation errors
   - Invalid credentials → auth error
   - Valid credentials → successful login
   - Logout → return to sign in

2. **Admin Flow**:
   - View home assistants list
   - Navigate to add assistant page
   - Form validation and error handling
   - Navigation consistency

3. **Grant Flow** (UI structure):
   - QR scanner page structure
   - Door opening page structure
   - Grant token handling (UI components)

### Dialogs and Modals
- Form validation errors
- Network error messages
- Loading indicators
- Modal bottom sheets (structure)
- Confirmation dialogs (structure)

### Error Scenarios
- Network connectivity issues
- Invalid form data
- Authentication failures
- Navigation edge cases
- State management consistency

## Development Integration

### Continuous Integration
The tests are designed to work in CI/CD environments:
- Docker-based execution (no local Flutter required)
- Automatic backend setup
- Headless testing support
- Comprehensive error reporting

### Local Development
For local development:
1. Run tests during feature development
2. Verify UI changes don't break existing flows
3. Test new screens and dialogs
4. Validate error handling

## Extending Tests

### Adding New Tests
1. **Screen Tests**: Add to `complete_ui_walkthrough_test.dart`
2. **Dialog Tests**: Add to `dialogs_and_grant_flow_test.dart`
3. **Flow Tests**: Add to `app_flow_test.dart`

### Test Structure
```dart
testWidgets('Test name', (WidgetTester tester) async {
  // Setup
  app.main();
  await tester.pumpAndSettle();
  
  // Test actions
  await tester.tap(find.text('Button'));
  await tester.pumpAndSettle();
  
  // Assertions
  expect(find.text('Expected Result'), findsOneWidget);
});
```

### Best Practices
- **Use descriptive test names**
- **Test both success and error paths**
- **Wait for UI updates** with `pumpAndSettle()`
- **Clean up state** between tests
- **Test real user interactions**

## Troubleshooting

### Common Issues

1. **PocketBase not starting**:
   ```bash
   docker compose -f docker-compose.dev.yml down
   docker compose -f docker-compose.dev.yml up -d pocketbase
   ```

2. **Flutter dependencies**:
   ```bash
   cd app
   flutter pub get
   ```

3. **Network connectivity**:
   - Ensure localhost:8080 is accessible
   - Check Docker network configuration

4. **Test timeouts**:
   - Increase timeout values for slow operations
   - Check backend health before running tests

### Debug Mode
Run tests with additional logging:
```bash
flutter test integration_test/ --verbose
```

## Architecture

The integration test suite follows this architecture:

```
┌─────────────────┐    HTTP     ┌─────────────────┐
│ Flutter Tests   │◄───────────►│ PocketBase      │
│ (Integration)   │             │ (Test Mode)     │
└─────────────────┘             └─────────────────┘
         │                               │
         ▼                               ▼
┌─────────────────┐             ┌─────────────────┐
│ Flutter Web App │             │ Test Data       │
│ (Test Instance) │             │ (Auto-created)  │
└─────────────────┘             └─────────────────┘
```

The tests interact with the actual application running in a test environment, providing realistic end-to-end validation of the complete system.