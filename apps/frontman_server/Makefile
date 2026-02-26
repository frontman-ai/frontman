# Task runner Makefile with auto-generated help
#
# Usage: make [target]
# Run 'make help' to see available commands

.DEFAULT_GOAL := help
.PHONY: help install test test-record test-coverage lint dev build clean check setup db-setup db-reset db-migrate db-seed assets-setup assets-build assets-deploy precommit dialyzer credo debug-task

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	mix deps.get

setup: ## Complete project setup (deps, database, assets)
	mix deps.get
	$(MAKE) db-setup
	$(MAKE) assets-setup
	$(MAKE) assets-build

db-setup: ## Setup database (create, migrate, seed)
	mix ecto.create
	mix ecto.migrate
	mix run priv/repo/seeds.exs

db-reset: ## Drop and recreate database
	mix ecto.drop
	$(MAKE) db-setup

db-migrate: ## Run database migrations
	mix ecto.migrate

db-seed: ## Seed database with data
	mix run priv/repo/seeds.exs

assets-setup: ## Install asset build tools (tailwind, esbuild)
	mix tailwind.install --if-missing
	mix esbuild.install --if-missing

assets-build: ## Build assets for development
	mix compile
	mix tailwind frontman_server
	mix esbuild frontman_server
	mix esbuild browser_test

assets-deploy: ## Build and minify assets for production
	mix tailwind frontman_server --minify
	mix esbuild frontman_server --minify
	mix esbuild browser_test --minify
	mix phx.digest

test: ## Run test suite and type checking
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	mix test
	mix dialyzer

test-record: ## Record new LLM fixtures (makes real API calls)
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	REQ_LLM_FIXTURES_MODE=record mix test

test-coverage: ## Run tests with coverage report
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	MIX_ENV=test mix coveralls.cobertura

lint: ## Run formatter and static analysis
	mix format
	mix credo --strict

dev: ## Start development server (resolves 1Password secrets via op run)
	op run --env-file=envs/.dev.secrets.env -- mix phx.server

build: ## Build the project for production
	MIX_ENV=prod mix sentry.package_source_code
	MIX_ENV=prod mix compile

clean: ## Clean build artifacts and dependencies
	rm -rf _build deps

precommit: ## Run precommit checks (compile, format, credo, test)
	mix compile --warning-as-errors
	mix deps.unlock --unused
	mix format
	mix credo --strict
	mix test

dialyzer: ## Run Dialyzer type checking
	mix dialyzer

credo: ## Run Credo static analysis
	mix credo --strict

check: lint dialyzer test ## Run all checks (lint + test)

debug-task: ## Debug task interactions (use ARGS="list" or ARGS="show ...")
	op run --env-file=envs/.dev.secrets.env -- mix debug_task $(ARGS)
