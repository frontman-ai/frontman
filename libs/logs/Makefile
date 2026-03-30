.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage build clean lint format check dev

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	yarn install

build: ## Build the project
	yarn rescript build

dev: ## Build the project in watch mode
	yarn rescript watch

test: build ## Run test suite
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest watch

test-coverage: build ## Run tests with coverage
	yarn vitest run --coverage

lint: ## Check code formatting
	yarn rescript format --check

format: ## Format code
	yarn rescript format -all

check: lint test ## Run all checks (lint + test)

clean: ## Clean build artifacts and temporary files
	rm -rf src/*.res.mjs src/*.res.mjs.map test/*.res.mjs test/*.res.mjs.map
