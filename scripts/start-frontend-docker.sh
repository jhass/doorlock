#!/bin/bash
# Start Flutter development server using Docker only

set -e

echo "🎨 Starting Flutter development server (Docker mode)..."

# Check if PocketBase is running
if ! docker compose -f docker-compose.dev.yml ps pocketbase | grep -q "Up"; then
    echo "❌ PocketBase is not running. Start it first with: ./scripts/setup-dev.sh"
    exit 1
fi

echo "✅ PocketBase is running"

# Use Flutter container for development
echo "🐳 Starting Flutter development container..."
docker compose -f docker-compose.dev.yml up app_dev