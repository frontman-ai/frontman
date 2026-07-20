.DEFAULT_GOAL := help
.PHONY: help install test dev build deploy blog-cover

PORT ?= 4321

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

test: ## Run marketing tests
	yarn run -T vitest run src/integrations/*.test.mjs

dev: ## Start development server
	yarn dev --port $(PORT)

build: ## Build for production
	yarn build

deploy: build ## Build and deploy to Cloudflare Pages
	op run --env-file=../../.env -- npx wrangler pages deploy dist --project-name=frontman-marketing --branch=main

blog-cover: ## Generate blog cover image — usage: make blog-cover TITLE="Your Title" [FILE=output-name]
	@test -n "$(TITLE)" || (echo "Usage: make blog-cover TITLE=\"Your Title\" [FILE=output-name]" && exit 1)
	node scripts/generate-blog-cover.mjs "$(TITLE)" $(FILE)
