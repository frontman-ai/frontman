# Task runner Makefile with auto-generated help.

.DEFAULT_GOAL := help
.PHONY: help install test format lint build release precommit clean

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	mix deps.get

test: ## Run test suite
	mix test

format: ## Auto-format Elixir files
	mix format

lint: ## Run formatter and static analysis
	mix format --check-formatted
	mix credo --strict

build: ## Compile for production
	MIX_ENV=prod mix compile --warnings-as-errors --all-warnings

release: build ## Build production release tarball
	MIX_ENV=prod mix release --overwrite

precommit: ## Run precommit checks
	mix compile --warnings-as-errors --all-warnings
	mix deps.unlock --unused
	mix format
	mix credo --strict
	mix test

clean: ## Clean build artifacts and dependencies
	rm -rf _build deps
