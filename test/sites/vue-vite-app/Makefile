.DEFAULT_GOAL := help
.PHONY: help install dev build preview type-check clean

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

dev: ## Start development server
	yarn dev

build: ## Build for production (runs vue-tsc first)
	yarn build

preview: ## Preview production build
	yarn preview

type-check: ## Run vue-tsc type checking
	yarn type-check

clean: ## Clean build artifacts
	rm -rf dist node_modules/.vite
