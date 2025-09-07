#!/bin/bash
# Run integration tests for the Doorlock app

set -e

echo "🧪 Running Doorlock Integration Tests..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Must be run from the app directory"
    echo "   Usage: cd app && ../scripts/run-integration-tests.sh"
    exit 1
fi

# Check if PocketBase is running
if ! curl -f http://localhost:8080/api/health &> /dev/null; then
    echo "⚠️  PocketBase is not running. Starting test environment..."
    cd ..
    ./scripts/start-integration-test.sh &
    TEST_ENV_PID=$!
    cd app
    
    # Wait for backend to be ready
    echo "⏳ Waiting for test environment..."
    timeout=30
    while ! curl -f http://localhost:8080/api/health &> /dev/null; do
        sleep 1
        timeout=$((timeout - 1))
        if [ $timeout -eq 0 ]; then
            echo "❌ Test environment failed to start"
            kill $TEST_ENV_PID 2>/dev/null || true
            exit 1
        fi
    done
    echo "✅ Test environment ready"
else
    echo "✅ PocketBase is already running"
fi

# Install dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Run integration tests
echo "🚀 Running integration tests..."

# Run all integration tests
if [ "$1" = "--all" ] || [ "$1" = "" ]; then
    echo "Running all integration tests..."
    flutter test integration_test/
elif [ "$1" = "--ui" ]; then
    echo "Running UI walkthrough tests..."
    flutter test integration_test/complete_ui_walkthrough_test.dart
elif [ "$1" = "--flow" ]; then
    echo "Running app flow tests..."
    flutter test integration_test/app_flow_test.dart
elif [ "$1" = "--dialogs" ]; then
    echo "Running dialogs and grant flow tests..."
    flutter test integration_test/dialogs_and_grant_flow_test.dart
else
    echo "Running specific test: $1"
    flutter test "$1"
fi

echo ""
echo "✅ Integration tests completed!"
echo ""
echo "💡 Test options:"
echo "   --all     : Run all integration tests (default)"
echo "   --ui      : Run UI walkthrough tests only"
echo "   --flow    : Run app flow tests only"
echo "   --dialogs : Run dialogs and grant flow tests only"
echo "   <file>    : Run specific test file"

# Cleanup if we started the test environment
if [ ! -z "$TEST_ENV_PID" ]; then
    echo "🧹 Cleaning up test environment..."
    kill $TEST_ENV_PID 2>/dev/null || true
    sleep 2
    docker compose -f ../docker-compose.dev.yml down > /dev/null 2>&1 || true
fi