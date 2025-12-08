.DEFAULT_GOAL := help
.PHONY: help build test test-watch lint clean

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build TypeScript
	yarn vite build

test: ## Run tests
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest

lint: ## Check TypeScript types
	yarn tsc --noEmit

clean: ## Clean build artifacts
	rm -rf dist


