#!/bin/bash

set -e

echo "🚀 Starting Doorlock Integration Tests"
echo "======================================="

# Configuration
POCKETBASE_PORT=8080
MOCK_HA_PORT=8123
APP_PORT=8090

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_status "$service_name is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts - waiting for $service_name..."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name did not start within $max_attempts seconds"
    return 1
}

# Function to cleanup processes
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    
    # Stop Docker containers
    if docker compose -f docker-compose.dev.yml ps pocketbase 2>/dev/null | grep -q "Up"; then
        echo "Stopping PocketBase container..."
        docker compose -f docker-compose.dev.yml stop pocketbase
    fi
    
    # Kill any remaining processes on our ports
    for port in $POCKETBASE_PORT $MOCK_HA_PORT $APP_PORT; do
        if check_port $port; then
            echo "Killing process on port $port..."
            lsof -ti:$port | xargs kill -9 2>/dev/null || true
        fi
    done
    
    print_status "Cleanup complete"
}

# Set up trap to cleanup on exit
trap cleanup EXIT

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is required but not installed"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is required but not installed"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    print_error "Flutter is required but not installed"
    exit 1
fi

print_status "Prerequisites check passed"

# Check if ports are available
for port in $POCKETBASE_PORT $MOCK_HA_PORT $APP_PORT; do
    if check_port $port; then
        print_warning "Port $port is in use. Attempting to free it..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
        if check_port $port; then
            print_error "Could not free port $port. Please stop the process using this port."
            exit 1
        fi
    fi
done

print_status "Ports are available"

# Start PocketBase
echo ""
echo "Starting PocketBase..."
cd "$(dirname "$0")/.."

# Ensure pb_data directory exists
mkdir -p pb_data

# Start PocketBase in the background
docker compose -f docker-compose.dev.yml up -d pocketbase

# Wait for PocketBase to be ready
if wait_for_service "http://localhost:$POCKETBASE_PORT/api/health" "PocketBase"; then
    print_status "PocketBase started successfully"
else
    print_error "Failed to start PocketBase"
    exit 1
fi

# Navigate to app directory
cd app

# Install dependencies
echo ""
echo "Installing Flutter dependencies..."
flutter pub get

# Run integration tests
echo ""
echo "🧪 Running Integration Tests"
echo "============================"

# Set environment variables for the test
export POCKETBASE_URL="http://localhost:$POCKETBASE_PORT"

# Run the integration tests
echo "Starting integration test runner..."

if flutter test test/integration_test.dart --timeout=300; then
    print_status "All integration tests passed!"
    echo ""
    echo "📊 Test Summary"
    echo "==============="
    echo "✅ Complete user journey test"
    echo "✅ Grant expiration workflow"
    echo "✅ Grant deletion workflow"
    echo "✅ Invalid Home Assistant handling"
    echo "✅ QR code scanning workflow"
    echo "✅ Door opening API verification"
    echo ""
    print_status "Integration test suite completed successfully!"
else
    print_error "Integration tests failed!"
    echo ""
    echo "💡 Troubleshooting Tips:"
    echo "- Check that PocketBase is running: curl http://localhost:$POCKETBASE_PORT/api/health"
    echo "- Check Docker logs: docker compose -f ../docker-compose.dev.yml logs pocketbase"
    echo "- Verify Flutter dependencies: flutter doctor"
    exit 1
fi