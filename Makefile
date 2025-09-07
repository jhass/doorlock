.PHONY: help dev-setup dev-start dev-stop dev-restart dev-logs dev-clean test-setup integration-test integration-test-ui integration-test-dialogs

help: ## Show this help message
	@echo "Doorlock Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
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

# Integration testing commands
integration-test: ## Run all integration tests
	@cd app && ../scripts/run-integration-tests.sh --all

integration-test-ui: ## Run UI walkthrough integration tests
	@cd app && ../scripts/run-integration-tests.sh --ui

integration-test-dialogs: ## Run dialogs and grant flow integration tests
	@cd app && ../scripts/run-integration-tests.sh --dialogs