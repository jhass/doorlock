#!/bin/bash

# Integration Test Environment Setup
# Sets up and seeds PocketBase with test data for manual integration testing

set -e

echo "🧪 Setting up Integration Test Environment"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "docker-compose.dev.yml" ]; then
    echo "❌ Must be run from the project root directory"
    exit 1
fi

echo "🗄️  Starting PocketBase with Docker..."
docker compose -f docker-compose.dev.yml up -d pocketbase

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

echo "✅ PocketBase is ready at http://localhost:8080"

echo "🌱 Seeding test data..."

# Wait a bit more for PocketBase to fully initialize
sleep 3

# Create admin user (might already exist)
echo "👤 Creating admin user..."
curl -X POST http://localhost:8080/api/admins \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@admin.com",
    "password": "test123456789",
    "passwordConfirm": "test123456789"
  }' > /dev/null 2>&1 && echo "  ✅ Created admin user" || echo "  📋 Admin user may already exist"

# Wait for admin user to be available
sleep 2

# Get admin token
echo "🔑 Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/admins/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{
    "identity": "test@admin.com",
    "password": "test123456789"
  }' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
    echo "⚠️  Could not get admin token. PocketBase might need manual admin setup."
    echo "   Visit http://localhost:8080/_/ to set up admin user manually"
    echo "   Use: test@admin.com / test123456789"
    echo ""
    echo "🎯 Environment is ready for manual testing!"
    echo "   - PocketBase: http://localhost:8080"
    echo "   - To test: cd app && flutter run -d web-server --web-port 8090"
    exit 0
fi

echo "✅ Got admin token"

# Create test users
echo "👤 Creating test users..."
curl -X POST http://localhost:8080/api/collections/doorlock_users/records \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "username": "testuser",
    "password": "testpass123",
    "passwordConfirm": "testpass123",
    "email": "testuser@example.com"
  }' > /dev/null 2>&1 && echo "  ✅ Created user: testuser" || echo "  📋 User testuser may already exist"

curl -X POST http://localhost:8080/api/collections/doorlock_users/records \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "username": "alice",
    "password": "alice123",
    "passwordConfirm": "alice123",
    "email": "alice@example.com"
  }' > /dev/null 2>&1 && echo "  ✅ Created user: alice" || echo "  📋 User alice may already exist"

# Get test user ID
USER_ID=$(curl -X GET "http://localhost:8080/api/collections/doorlock_users/records?filter=username='testuser'" \
  -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ ! -z "$USER_ID" ]; then
    echo "✅ Got test user ID: $USER_ID"
    
    # Create test Home Assistants
    echo "🏠 Creating test Home Assistant instances..."
    curl -X POST http://localhost:8080/api/collections/home_assistants/records \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d "{
        \"user\": \"$USER_ID\",
        \"name\": \"Test Home\",
        \"url\": \"http://localhost:8123\",
        \"access_token\": \"mock_token_1\"
      }" > /dev/null 2>&1 && echo "  ✅ Created Home Assistant: Test Home" || echo "  📋 Home Assistant 'Test Home' may already exist"
    
    curl -X POST http://localhost:8080/api/collections/home_assistants/records \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d "{
        \"user\": \"$USER_ID\",
        \"name\": \"Office HA\",
        \"url\": \"http://office.local:8123\",
        \"access_token\": \"mock_token_2\"
      }" > /dev/null 2>&1 && echo "  ✅ Created Home Assistant: Office HA" || echo "  📋 Home Assistant 'Office HA' may already exist"
else
    echo "⚠️  Could not get test user ID, skipping Home Assistant creation"
fi

echo ""
echo "🎯 Integration Test Environment Ready!"
echo ""
echo "📊 Test Data Summary:"
echo "   - PocketBase: http://localhost:8080"
echo "   - Admin: test@admin.com / test123456789"
echo "   - Test Users: testuser/testpass123, alice/alice123"
echo "   - Mock Home Assistants: Test Home (localhost:8123), Office HA"
echo ""
echo "🧪 Manual Integration Testing:"
echo "   1. Start the app: cd app && flutter run -d web-server --web-port 8090"
echo "   2. Navigate to: http://localhost:8090"
echo "   3. Sign in with: testuser / testpass123"
echo "   4. Test Home Assistant management and door unlock flows"
echo ""
echo "💡 To run widget tests against this data:"
echo "   make widget-test"
echo ""
echo "🛑 To stop the environment:"
echo "   docker compose -f docker-compose.dev.yml down"