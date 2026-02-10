.DEFAULT_GOAL := help
.PHONY: help install dev build deploy

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

dev: ## Start development server
	yarn dev

build: ## Build for production
	yarn build

deploy: build ## Build and deploy to Cloudflare Pages
	op run --env-file=../../.env -- npx wrangler pages deploy dist --project-name=frontman-marketing --branch=main
