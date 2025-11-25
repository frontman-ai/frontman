.DEFAULT_GOAL := help
.PHONY: help install test test-watch build clean lint format check serve

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	yarn install

build: ## Build the project
	yarn rescript build

test: build ## Run test suite
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest watch

lint: ## Check code formatting
	yarn rescript format -check

format: ## Format code
	yarn rescript format -all

check: lint test ## Run all checks (lint + test)

clean: ## Clean build artifacts and temporary files
	rm -rf src/*.res.mjs src/*.res.mjs.map test/*.res.mjs test/*.res.mjs.map

serve: build ## Serve browser test page (requires Phoenix server running)
	@echo "Starting dev server at http://localhost:5173/browser-test/"
	@echo "Make sure Phoenix server is running at ws://localhost:4000/socket"
	npx vite --open /browser-test/index.html
