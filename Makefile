.DEFAULT_GOAL := help
.PHONY: help install build clean dev test lint dev-client dev-nextjs pull-webapi

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build ReScript project
	yarn rescript

clean: ## Clean build artifacts
	yarn rescript clean

dev: ## Watch and rebuild on changes
	yarn rescript watch

test: ## Run tests
	# Add test commands here

lint: ## Run linters
	# Add lint commands here

dev-client: ## Start development server for client app
	cd libs/client && $(MAKE) dev-server

dev-nextjs: ## Start development server for Next.js test site
	cd test/sites/blog-starter && $(MAKE) dev

pull-webapi: ## Pull latest changes from experimental-rescript-webapi subtree
	git subtree pull --prefix libs/experimental-rescript-webapi git@github.com:itayadler/experimental-rescript-webapi.git main --squash
