#!/bin/bash
# Start the complete environment for integration testing

set -e

echo "🧪 Setting up integration test environment..."

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up test environment..."
    docker compose -f docker-compose.dev.yml down > /dev/null 2>&1 || true
    # Kill any remaining Flutter processes
    pkill -f "flutter.*web-server" > /dev/null 2>&1 || true
    exit 0
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Start PocketBase backend
echo "🔧 Starting PocketBase backend..."
docker compose -f docker-compose.dev.yml up -d pocketbase

# Wait for PocketBase to be ready
echo "⏳ Waiting for PocketBase to be ready..."
timeout=30
while ! curl -f http://localhost:8080/api/health &> /dev/null; do
    sleep 1
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        echo "❌ PocketBase failed to start"
        exit 1
    fi
done

echo "✅ PocketBase is ready"

# Setup test data if needed
echo "📊 Setting up test data..."
# Create a test user for integration tests
curl -X POST http://localhost:8080/api/collections/doorlock_users/records \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "testpass123",
    "passwordConfirm": "testpass123"
  }' > /dev/null 2>&1 || echo "  (Test user may already exist)"

echo "🎯 Test environment is ready!"
echo "   PocketBase: http://localhost:8080"
echo "   Test user: testuser / testpass123"
echo ""
echo "💡 Run integration tests with: cd app && flutter test integration_test/"
echo "   Or run specific test: flutter test integration_test/app_flow_test.dart"
echo ""
echo "🔄 Press Ctrl+C to stop the test environment"

# Keep the script running to maintain the environment
while true; do
    sleep 10
    # Check if PocketBase is still running
    if ! curl -f http://localhost:8080/api/health &> /dev/null; then
        echo "⚠️  PocketBase stopped running"
        break
    fi
done