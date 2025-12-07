.DEFAULT_GOAL := help
.PHONY: help install dev build

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

dev: ## Start development server
	yarn dev

build: ## Build for production
	yarn build
