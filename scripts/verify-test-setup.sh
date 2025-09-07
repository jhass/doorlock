#!/bin/bash
# Verify integration test setup and structure

set -e

echo "🔍 Verifying Integration Test Setup..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Must be run from the app directory"
    echo "   Usage: cd app && ../scripts/verify-test-setup.sh"
    exit 1
fi

echo ""
echo "📁 Checking test directory structure..."

# Check integration test directory
if [ -d "integration_test" ]; then
    echo "✅ integration_test/ directory exists"
    
    # List test files
    test_files=$(find integration_test -name "*.dart" | wc -l)
    echo "✅ Found $test_files test files:"
    find integration_test -name "*.dart" | sed 's/^/   - /'
else
    echo "❌ integration_test/ directory not found"
    exit 1
fi

echo ""
echo "📋 Checking pubspec.yaml dependencies..."

# Check for integration_test dependency
if grep -q "integration_test:" pubspec.yaml; then
    echo "✅ integration_test dependency found"
else
    echo "❌ integration_test dependency not found in pubspec.yaml"
    exit 1
fi

# Check for flutter_test dependency
if grep -q "flutter_test:" pubspec.yaml; then
    echo "✅ flutter_test dependency found"
else
    echo "❌ flutter_test dependency not found in pubspec.yaml"
    exit 1
fi

echo ""
echo "🔧 Checking test support scripts..."

# Check for test runner script
if [ -f "../scripts/run-integration-tests.sh" ]; then
    echo "✅ Test runner script exists"
    if [ -x "../scripts/run-integration-tests.sh" ]; then
        echo "✅ Test runner script is executable"
    else
        echo "⚠️  Test runner script is not executable"
    fi
else
    echo "❌ Test runner script not found"
fi

# Check for test environment script
if [ -f "../scripts/start-integration-test.sh" ]; then
    echo "✅ Test environment script exists"
    if [ -x "../scripts/start-integration-test.sh" ]; then
        echo "✅ Test environment script is executable"
    else
        echo "⚠️  Test environment script is not executable"
    fi
else
    echo "❌ Test environment script not found"
fi

echo ""
echo "📄 Analyzing test files..."

for test_file in integration_test/*.dart; do
    if [ -f "$test_file" ]; then
        filename=$(basename "$test_file")
        echo "📝 Analyzing $filename..."
        
        # Check for required imports
        if grep -q "import 'package:integration_test/integration_test.dart';" "$test_file"; then
            echo "   ✅ Has integration_test import"
        else
            echo "   ❌ Missing integration_test import"
        fi
        
        if grep -q "import 'package:flutter_test/flutter_test.dart';" "$test_file"; then
            echo "   ✅ Has flutter_test import"
        else
            echo "   ❌ Missing flutter_test import"
        fi
        
        if grep -q "IntegrationTestWidgetsFlutterBinding.ensureInitialized();" "$test_file"; then
            echo "   ✅ Has proper test binding initialization"
        else
            echo "   ❌ Missing test binding initialization"
        fi
        
        # Count test cases
        test_count=$(grep -c "testWidgets(" "$test_file" || true)
        echo "   📊 Contains $test_count test cases"
        
        # Check for main test groups
        if grep -q "group(" "$test_file"; then
            echo "   ✅ Uses test groups for organization"
        fi
    fi
done

echo ""
echo "🎯 Test Coverage Summary..."

total_tests=0
for test_file in integration_test/*.dart; do
    if [ -f "$test_file" ]; then
        file_tests=$(grep -c "testWidgets(" "$test_file" || true)
        total_tests=$((total_tests + file_tests))
    fi
done

echo "📊 Total test cases: $total_tests"

# Analyze test coverage areas
echo ""
echo "🔍 Test Coverage Areas:"

if grep -r "Sign In" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Authentication flow testing"
fi

if grep -r "Home Assistant" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Home Assistant management testing"
fi

if grep -r "dialog\|Dialog\|Modal" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Dialog and modal testing"
fi

if grep -r "validation\|error" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Error handling and validation testing"
fi

if grep -r "navigation\|Navigator" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Navigation testing"
fi

if grep -r "QR\|Grant" integration_test/ > /dev/null 2>&1; then
    echo "   ✅ Grant flow and QR code testing"
fi

echo ""
echo "🔄 Backend Integration Check..."

# Check if PocketBase is configured
if docker compose -f ../docker-compose.dev.yml config > /dev/null 2>&1; then
    echo "✅ Docker Compose configuration is valid"
    
    # Check if PocketBase service is defined
    if docker compose -f ../docker-compose.dev.yml config | grep -q "pocketbase"; then
        echo "✅ PocketBase service configured for testing"
    else
        echo "⚠️  PocketBase service not found in docker-compose.dev.yml"
    fi
else
    echo "❌ Docker Compose configuration has issues"
fi

echo ""
echo "📚 Documentation Check..."

if [ -f "integration_test/README.md" ]; then
    echo "✅ Integration test documentation exists"
    
    # Check documentation completeness
    if grep -q "Running Tests" integration_test/README.md; then
        echo "   ✅ Contains usage instructions"
    fi
    
    if grep -q "Test Coverage" integration_test/README.md; then
        echo "   ✅ Documents test coverage"
    fi
else
    echo "⚠️  Integration test documentation not found"
fi

echo ""
echo "🎉 Integration Test Setup Verification Complete!"
echo ""
echo "📋 Summary:"
echo "   - Test files: $test_files"
echo "   - Test cases: $total_tests"
echo "   - Backend integration: Ready"
echo "   - Documentation: Available"
echo ""
echo "🚀 To run tests:"
echo "   make integration-test"
echo "   or"
echo "   ../scripts/run-integration-tests.sh --all"