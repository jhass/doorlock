#!/bin/bash

set -e

POCKETBASE_PORT=8080
SCRIPT_DIR="$(dirname "$0")"

cleanup() {
    docker compose -f "$SCRIPT_DIR/../docker-compose.dev.yml" stop pocketbase 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting PocketBase..."
cd "$SCRIPT_DIR/.."
docker compose -f docker-compose.dev.yml up -d pocketbase

echo "Waiting for PocketBase..."
for i in $(seq 1 30); do
    curl -fs "http://localhost:$POCKETBASE_PORT/api/health" > /dev/null && break
    [ "$i" -eq 30 ] && echo "PocketBase did not start" && exit 1
    sleep 1
done

cd app
flutter pub get
POCKETBASE_URL="http://localhost:$POCKETBASE_PORT" flutter test test/integration_test.dart --timeout=300s
