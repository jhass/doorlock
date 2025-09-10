#!/bin/bash

set -e

echo "🚀 Running Doorlock CI Tests"
echo "============================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Navigate to app directory
cd "$(dirname "$0")/../app"

# Install dependencies
echo "Installing Flutter dependencies..."
flutter pub get

# Run static analysis
echo ""
echo "🔍 Running Static Analysis"
echo "=========================="
if flutter analyze; then
    print_status "Static analysis passed"
else
    print_error "Static analysis failed"
    exit 1
fi

# Run integration tests (infrastructure validation only - no Docker required)
echo ""
echo "🧪 Running Integration Tests"
echo "============================"
echo "Running infrastructure validation tests..."

if flutter test test/integration_test.dart --timeout=60s; then
    print_status "All integration tests passed!"
    echo ""
    echo "📊 Test Summary"
    echo "==============="
    echo "✅ Environment configuration test"
    echo "✅ Service dependency injection test"
    echo "✅ Mock server management test"
    echo "✅ Mock Home Assistant integration test"
    echo "✅ Complete test infrastructure validation"
    echo ""
    print_status "CI test suite completed successfully!"
else
    print_error "Integration tests failed!"
    exit 1
fi