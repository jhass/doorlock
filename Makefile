.PHONY: help dev-setup dev-start dev-stop dev-restart dev-logs dev-clean test-setup

help: ## Show this help message
	@echo "Doorlock Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

dev-setup: ## Set up development environment (start PocketBase)
	./scripts/setup-dev.sh

dev-start: ## Start frontend development server
	./scripts/start-frontend.sh

dev-stop: ## Stop all development services
	docker compose -f docker-compose.dev.yml down

dev-restart: ## Restart backend after changes
	./scripts/restart-backend.sh

dev-logs: ## Show development logs
	docker compose -f docker-compose.dev.yml logs -f

dev-clean: ## Clean up development environment (removes data!)
	docker compose -f docker-compose.dev.yml down -v
	rm -rf pb_data

test-setup: ## Test if development environment is working
	@echo "🧪 Testing development environment..."
	@echo "1. Checking Docker..."
	@docker --version > /dev/null && echo "  ✅ Docker is available" || echo "  ❌ Docker not found"
	@docker compose version > /dev/null && echo "  ✅ Docker Compose is available" || echo "  ❌ Docker Compose not found"
	@echo "2. Checking PocketBase..."
	@docker compose -f docker-compose.dev.yml ps pocketbase | grep -q "Up" && echo "  ✅ PocketBase is running" || echo "  ❌ PocketBase is not running"
	@echo "3. Checking ports..."
	@curl -s http://localhost:8080 > /dev/null && echo "  ✅ Port 8080 is accessible" || echo "  ❌ Port 8080 is not accessible"
	@echo "4. Checking Flutter..."
	@command -v flutter > /dev/null && echo "  ✅ Flutter is available" || echo "  ⚠️  Flutter not found (will use Docker)"
	@echo ""
	@echo "🎯 Setup complete! Next steps:"
	@echo "   1. Access PocketBase admin: http://localhost:8080/_/"
	@echo "   2. Create a doorlock_users record"
	@echo "   3. Start frontend: make dev-start"

# Quick development workflow
dev: dev-setup ## Quick start: setup and start development environment
	@echo "🚀 Starting development environment..."
	@echo "   Backend: http://localhost:8080"
	@echo "   Frontend: http://localhost:8090 (after running 'make dev-start')"
	@echo ""
	@echo "💡 Next: run 'make dev-start' in a new terminal to start the frontend"

PB_VERSION ?= 0.28.2

install-pb-test: ## Download PocketBase binary for tests (tools/pocketbase)
	@mkdir -p tools
	@OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	ARCH=$$(uname -m); \
	if [ "$$ARCH" = "x86_64" ]; then ARCH="amd64"; fi; \
	if [ "$$ARCH" = "arm64" ]; then ARCH="arm64"; fi; \
	curl -L \
		"https://github.com/pocketbase/pocketbase/releases/download/v$(PB_VERSION)/pocketbase_$(PB_VERSION)_$${OS}_$${ARCH}.zip" \
		-o /tmp/pb.zip && \
	unzip -o /tmp/pb.zip -d tools/ && \
	chmod +x tools/pocketbase
	@echo "PocketBase $(PB_VERSION) installed at tools/pocketbase"

test: ## Run widget tests (Dart VM) - requires pocketbase binary
	cd app && flutter test --reporter expanded

integration-test: ## Run Chrome integration tests - requires pocketbase binary and Chrome
	cd app && dart run tool/start_test_infra.dart

test-all: test integration-test ## Run all tests