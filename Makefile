.PHONY: help test-build test test-shell

TEST_IMAGE ?= doorlock-local-test:dev
TEST_DOCKERFILE ?= docker/local-test/Dockerfile
TEST_FAIL_FAST ?= 0
TEST_PLATFORM ?= linux/amd64

help: ## Show available local test commands
	@echo "Doorlock Local Test Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

test-build: ## Build the local test image
	docker build --platform $(TEST_PLATFORM) -f $(TEST_DOCKERFILE) -t $(TEST_IMAGE) --load .

test: test-build ## Run local tests in the container (set TEST_FAIL_FAST=1 for fail-fast)
	docker run --platform $(TEST_PLATFORM) --rm -e TEST_FAIL_FAST=$(TEST_FAIL_FAST) $(TEST_IMAGE)

test-shell: test-build ## Open a shell in the local test container
	docker run --platform $(TEST_PLATFORM) --rm -it -e TEST_FAIL_FAST=$(TEST_FAIL_FAST) --entrypoint /bin/bash $(TEST_IMAGE)