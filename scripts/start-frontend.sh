#!/bin/bash
# Start Flutter development server

set -e

echo "🎨 Starting Flutter development server..."

# Check if PocketBase is running
if ! docker compose -f docker-compose.dev.yml ps pocketbase | grep -q "Up"; then
    echo "❌ PocketBase is not running. Start it first with: ./scripts/setup-dev.sh"
    exit 1
fi

echo "✅ PocketBase is running"

# Navigate to the app directory
cd app

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter is not installed locally. Attempting to install..."
    
    # Try to install Flutter locally first
    echo "📦 Installing Flutter SDK..."
    cd ..
    if ./scripts/install-flutter.sh; then
        echo "✅ Flutter installed successfully"
        # Add Flutter to PATH for this session
        export PATH="/opt/flutter/bin:$PATH"
        cd app
        
        # Verify Flutter is working
        if ! flutter --version >/dev/null 2>&1; then
            echo "❌ Flutter installation incomplete due to network issues"
            echo "🐳 Falling back to Docker..."
            docker compose -f docker-compose.dev.yml up app_dev
            exit 0
        fi
    else
        echo "❌ Failed to install Flutter locally. Falling back to Docker..."
        echo "🐳 Starting Flutter development container..."
        docker compose -f docker-compose.dev.yml up app_dev
        exit 0
    fi
fi

echo "🚀 Using local Flutter installation"

# Install dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Start development server
echo "🌐 Starting Flutter web development server..."
echo "   Flutter app will be available at: http://localhost:8090"
echo "   PocketBase is running at: http://localhost:8080"
echo ""
echo "✨ Hot reload is enabled - make changes to your Dart files!"
echo ""

flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090