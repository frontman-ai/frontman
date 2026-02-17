.DEFAULT_GOAL := help
.PHONY: help build test test-watch lint format clean publish

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript + bundle with tsup
	yarn build

publish: build ## Build and publish to npm
	npm publish

test: build ## Run tests
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest

lint: ## Check formatting
	yarn rescript format -check src test

format: ## Format code
	yarn rescript format src test

clean: ## Clean build artifacts
	yarn rescript clean
