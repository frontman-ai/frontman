.DEFAULT_GOAL := help
.PHONY: help install test lint dev dev-hot build build-lib clean serve preview check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	npm install

test: ## Run test suite
	# Add test commands here when tests are implemented

lint: ## Run linters and code formatters
	eslint .

dev: ## Start development server with build watch
	$(MAKE) clean
	$(MAKE) -j2 dev-build-watch preview

dev-build-watch: ## Watch and build in development mode
	vite build --mode development --watch

dev-server: ## Start vite dev server
	vite

dev-hot: ## Start development server with hot reload
	vite --mode development

build: ## Build the project for production
	$(MAKE) clean
	tsc -b
	vite build

build-lib: ## Build the project as a library
	$(MAKE) clean
	vite build --mode library

clean: ## Clean build artifacts and temporary files
	rm -rf dist
	tsc -b --clean

serve: ## Serve production build
	vite preview --port 5173 --host

preview: ## Preview production build
	vite preview

check: lint ## Run all checks (lint + test)
