# Task runner Makefile for swarm_ai
#
# Usage: make [target]
# Run 'make help' to see available commands

.DEFAULT_GOAL := help
.PHONY: help install test test-coverage lint build clean check precommit dialyzer credo hex-publish

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	mix deps.get

test: ## Run test suite
	mix test

test-coverage: ## Run tests with coverage report
	MIX_ENV=test mix coveralls.cobertura

lint: ## Run formatter and static analysis
	mix format
	mix credo --strict

build: ## Compile the project
	mix compile

clean: ## Clean build artifacts and dependencies
	rm -rf _build deps

precommit: ## Run precommit checks (compile, format, credo, test)
	mix compile --warnings-as-errors
	mix deps.unlock --unused
	mix format
	mix credo --strict
	mix test

dialyzer: ## Run Dialyzer type checking
	mix dialyzer

credo: ## Run Credo static analysis
	mix credo --strict

check: lint test ## Run all checks (lint + test)

hex-publish: ## Publish package to Hex (dry run by default, use HEX_PUBLISH=1 for real)
	@if [ "$(HEX_PUBLISH)" = "1" ]; then \
		mix hex.publish; \
	else \
		mix hex.build; \
	fi
