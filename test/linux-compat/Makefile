.PHONY: help test build clean shell rayvn valt wardn all-at-once

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

test: ## Run all compatibility tests (build and test)
	docker compose up --build --abort-on-container-exit

build: ## Build the Docker image
	docker compose build

clean: ## Clean up Docker containers and images
	docker compose down --rmi local --volumes

shell: ## Open an interactive bash shell in the Linux container
	docker compose run --rm linux-test bash

rayvn: ## Run only rayvn tests
	@docker compose run --rm linux-test test-runner.sh rayvn

valt: ## Run only valt tests (if available)
	@docker compose run --rm linux-test test-runner.sh valt

wardn: ## Run only wardn tests (if available)
	@docker compose run --rm linux-test test-runner.sh wardn

all: ## Run all project tests in a single command
	@docker compose run --rm linux-test test-runner.sh

rebuild: clean build ## Clean and rebuild from scratch
	@echo "Rebuild complete"

verify: ## Quick verification of command compatibility
	@echo "Verifying command compatibility..."
	@docker compose run --rm linux-test bash -c "\
		echo 'Testing sed...'; \
		echo 'test123' | sed 's/[0-9]\+/NUM/' && \
		echo 'Testing date...'; \
		date -d @1234567890 '+%Y-%m-%d' && \
		echo 'Testing base64...'; \
		echo 'test' | base64 -w 65 && \
		echo 'All commands compatible!'"
