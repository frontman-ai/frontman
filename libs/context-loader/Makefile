.DEFAULT_GOAL := help
.PHONY: help install build dev clean test test-watch test-coverage lint format check

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build the project
	yarn rescript

dev: ## Start development watcher
	yarn rescript watch

clean: ## Clean build artifacts
	yarn rescript clean && rm -rf lib

test: build ## Run tests
	yarn vitest run

test-watch: ## Run tests in watch mode
	echo "Please run make dev on another shell to rebuild the source code"
	yarn vitest --inspect-brk --pool threads --poolOptions.threads.singleThread

test-coverage: build ## Run tests with coverage
	yarn vitest run --coverage

lint: ## Check code formatting
	yarn rescript format -check src

format: ## Format code
	yarn rescript format -all src

check: lint test ## Run all checks (lint + test)
