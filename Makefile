.PHONY: help dev-setup dev-start dev-stop dev-restart dev-logs dev-clean integration-test

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

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

dev: dev-setup ## Quick start: setup development environment

integration-test: ## Run integration tests
	./scripts/run_integration_tests.sh

