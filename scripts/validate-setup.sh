#!/bin/bash

# Validate that the development environment is properly set up

set -e

echo "=== Doorlock Development Environment Validation ==="

# Check Flutter
echo "Checking Flutter..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found"
    exit 1
fi

echo "✅ Flutter version: $(flutter --version | head -1)"

# Check Dart version compatibility
DART_VERSION=$(dart --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
MAJOR=$(echo $DART_VERSION | cut -d. -f1)
MINOR=$(echo $DART_VERSION | cut -d. -f2)

if [[ $MAJOR -gt 3 ]] || [[ $MAJOR -eq 3 && $MINOR -ge 8 ]]; then
    echo "✅ Dart version $DART_VERSION meets requirement ^3.8.1"
else
    echo "❌ Dart version $DART_VERSION does not meet requirement ^3.8.1"
    exit 1
fi

# Check Docker
echo "Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found"
    exit 1
fi

echo "✅ Docker version: $(docker --version)"

# Check app directory
echo "Checking app structure..."
if [[ ! -f "app/pubspec.yaml" ]]; then
    echo "❌ app/pubspec.yaml not found"
    exit 1
fi

echo "✅ App directory structure valid"

# Test Flutter dependencies
echo "Testing Flutter dependencies..."
cd app
if flutter pub get; then
    echo "✅ Flutter dependencies resolved successfully"
else
    echo "❌ Flutter dependencies failed to resolve"
    exit 1
fi

# Test basic Flutter commands
echo "Testing basic Flutter commands..."
if flutter analyze --no-fatal-infos > /dev/null 2>&1; then
    echo "✅ Flutter analyze passed"
else
    echo "⚠️  Flutter analyze found issues (non-fatal)"
fi

# Check PocketBase
if [[ "${SKIP_POCKETBASE:-}" != "1" ]]; then
    echo "Checking PocketBase..."
    if docker compose -f docker-compose.dev.yml ps | grep -q "Up"; then
        echo "✅ PocketBase is running"
        if curl -f http://localhost:8080/api/health &> /dev/null; then
            echo "✅ PocketBase API is accessible"
        else
            echo "⚠️  PocketBase API not accessible at localhost:8080"
        fi
    else
        echo "ℹ️  PocketBase not currently running (start with: docker compose -f docker-compose.dev.yml up -d)"
    fi
else
    echo "ℹ️  Skipping PocketBase checks (test mode)"
fi

echo ""
echo "🎉 Environment validation complete!"
echo ""
echo "Next steps:"
echo "  - Start backend: docker compose -f docker-compose.dev.yml up -d"
echo "  - Start frontend: cd app && flutter run -d web-server --web-port 8090"
echo "  - Access app: http://localhost:8090"
echo "  - Access PocketBase admin: http://localhost:8080/_/"