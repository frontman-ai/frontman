.DEFAULT_GOAL := help
.PHONY: help install test test-coverage lint format dev dev-hot build build-lib clean serve preview check storybook storybook-build

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	npm install

test: build ## Run test suite
	yarn vitest run

test-coverage: build ## Run tests with coverage
	yarn vitest run --coverage

lint: ## Run linters and code formatters
	yarn biome check .

format: ## Format code with biome
	yarn biome check --write .

dev: 
	yarn vite

dev-build-watch: ## Watch and build in development mode
	yarn vite build --mode development --watch

dev-hot: ## Start development server with hot reload
	yarn vite --mode development

build: ## Build the project for production
	$(MAKE) clean
	yarn rescript build

build-lib: ## Build the project as a library
	$(MAKE) clean
	yarn vite build --mode library

build-standalone: ## Build standalone bundle (React bundled) for Cloudflare Pages
	$(MAKE) clean
	yarn rescript build
	yarn vite build --config vite.config.standalone.ts

clean: ## Clean build artifacts and temporary files
	rm -rf dist

serve: ## Serve production build
	yarn vite preview --port 5173 --host

preview: ## Preview production build
	yarn vite preview

publish:
	$(MAKE) build-lib
	npm publish

check: lint ## Run all checks (lint + test)

storybook: ## Start Storybook development server
	yarn storybook

storybook-build: build ## Build Storybook for production
	yarn build-storybook
