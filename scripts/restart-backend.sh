#!/bin/bash
# Restart development environment after backend changes

set -e

echo "🔄 Restarting development environment after backend changes..."

# Restart PocketBase to pick up hook/migration changes
echo "🐳 Restarting PocketBase..."
docker compose -f docker-compose.dev.yml restart pocketbase

echo "⏳ Waiting for PocketBase to be ready..."
sleep 3

# Check if PocketBase is running
if curl -f http://localhost:8080/api/health &> /dev/null; then
    echo "✅ PocketBase restarted successfully"
else
    echo "⚠️  PocketBase might still be starting up. Check logs with: docker compose -f docker-compose.dev.yml logs pocketbase"
fi

echo ""
echo "🎯 Backend restart complete!"
echo "   Your Flutter development server should automatically reconnect"
echo ""