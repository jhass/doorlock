#!/bin/bash
# Development setup script for Doorlock app

set -e

echo "🚀 Setting up Doorlock development environment..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Check if Flutter is installed and offer to install it
if ! command -v flutter &> /dev/null; then
    echo ""
    echo "📱 Flutter is not installed locally."
    echo "   Flutter will be installed automatically when you run ./scripts/start-frontend.sh"
    echo "   Or you can install it now with: ./scripts/install-flutter.sh"
    echo ""
fi

# Create pb_data directory if it doesn't exist
if [ ! -d "pb_data" ]; then
    echo "📁 Creating pb_data directory..."
    mkdir -p pb_data
fi

# Start development environment
echo "🐳 Starting development containers..."
docker compose -f docker-compose.dev.yml up -d pocketbase

echo "⏳ Waiting for PocketBase to be ready..."
sleep 5

# Check if PocketBase is running
if curl -f http://localhost:8080/api/health &> /dev/null; then
    echo "✅ PocketBase is running at http://localhost:8080"
else
    echo "⚠️  PocketBase might still be starting up. Check logs with: docker compose -f docker-compose.dev.yml logs pocketbase"
fi

echo ""
echo "🎯 Development environment is ready!"
echo ""
echo "📋 Next steps:"
echo "   1. Set up a doorlock_users record via PocketBase admin UI at http://localhost:8080/_/"
echo "   2. Start the Flutter development server with: ./scripts/start-frontend.sh"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker compose -f docker-compose.dev.yml logs -f"
echo "   - Stop services: docker compose -f docker-compose.dev.yml down"
echo "   - Restart PocketBase: docker compose -f docker-compose.dev.yml restart pocketbase"
echo ""