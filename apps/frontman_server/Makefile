




.DEFAULT_GOAL := help
.PHONY: help install test test-record test-coverage format lint dev dev-container build clean check setup db-setup db-reset db-migrate db-seed assets-setup assets-build assets-deploy precommit strict-compile credo debug-task

SHELL := /bin/bash
OP_RUN := op run --env-file=envs/.dev.secrets.env --

HELP_TARGETS := help install setup db-setup db-reset db-migrate db-seed assets-setup assets-build assets-deploy test test-record test-coverage format lint security dev dev-container build clean precommit credo check debug-task
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_setup := Complete project setup (deps, database, assets)
HELP_db-setup := Setup database (create, migrate, seed)
HELP_db-reset := Drop and recreate database
HELP_db-migrate := Run database migrations
HELP_db-seed := Seed database with data
HELP_assets-setup := Install asset build tools (tailwind, esbuild)
HELP_assets-build := Build assets for development
HELP_assets-deploy := Build and minify assets for production
HELP_test := Run test suite
HELP_test-record := Record new LLM fixtures (makes real API calls)
HELP_test-coverage := Run tests with coverage report
HELP_format := Auto-format Elixir files
HELP_lint := Run formatter and static analysis
HELP_security := Check unused dependencies, Hex advisories, and Sobelow findings
HELP_dev := Start development server (resolves 1Password secrets via op run)
HELP_dev-container := Start dev server inside container (secrets via env vars)
HELP_build := Build the project for production
HELP_clean := Clean build artifacts and dependencies
HELP_precommit := Run precommit checks (compile, format, credo, test)
HELP_credo := Run Credo static analysis
HELP_check := Run all checks (lint + test)
HELP_debug-task := Debug task interactions (use ARGS="list" or ARGS="show ...")

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	mix deps.get

setup:
	mix deps.get
	$(MAKE) db-setup
	$(MAKE) assets-setup
	$(MAKE) assets-build

db-setup:
	$(OP_RUN) mix ecto.create
	$(OP_RUN) mix ecto.migrate
	$(OP_RUN) mix run priv/repo/seeds.exs

db-reset:
	$(OP_RUN) mix ecto.drop
	$(MAKE) db-setup

db-migrate:
	$(OP_RUN) mix ecto.migrate

db-seed:
	$(OP_RUN) mix run priv/repo/seeds.exs

assets-setup:
	mix tailwind.install --if-missing
	mix esbuild.install --if-missing

assets-build:
	mix compile
	mix tailwind frontman_server
	mix esbuild frontman_server
	mix esbuild browser_test

assets-deploy:
	mix tailwind frontman_server --minify
	mix esbuild frontman_server --minify
	mix esbuild browser_test --minify
	mix phx.digest

test:
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	mix test $(TEST_ARGS)

.PHONY: test-application-restart
test-application-restart:
	@set -eu; \
	export MIX_ENV=test MIX_TEST_PARTITION=""; \
	MIX_TEST_DB_SUFFIX="_restart_$$(elixir -e 'IO.write(Base.encode16(:crypto.strong_rand_bytes(16), case: :lower))')"; \
	export MIX_TEST_DB_SUFFIX; \
	trap 'status=$$?; trap - EXIT; mix ecto.drop --quiet || { cleanup=$$?; [ "$$status" -ne 0 ] || status=$$cleanup; }; exit "$$status"' EXIT; \
	echo "Owned test database: frontman_server_test$$MIX_TEST_DB_SUFFIX"; \
	mix ecto.create --quiet; \
	mix ecto.migrate --quiet; \
	mix test --only application_restart --seed 0

test-record:
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	REQ_LLM_FIXTURES_MODE=record mix test

test-coverage:
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	MIX_ENV=test mix coveralls.cobertura

format:
	mix format $(FORMAT_ARGS)

lint:
	mix format --check-formatted
	mix credo --strict

.PHONY: security
security:
	mix deps.unlock --check-unused
	mix deps.get
	mix hex.audit
	mix sobelow --config --exit

dev:
	$(OP_RUN) mix phx.server

dev-container:
	mix phx.server

build:
	MIX_ENV=prod mix sentry.package_source_code
	MIX_ENV=prod mix compile --warnings-as-errors --all-warnings

clean:
	rm -rf _build deps

precommit:
	mix compile --warnings-as-errors --all-warnings
	mix deps.unlock --unused
	mix format
	mix credo --strict
	$(MAKE) test

strict-compile:
	mix compile --warnings-as-errors --all-warnings
	MIX_ENV=test mix compile --warnings-as-errors --all-warnings

credo:
	mix credo --strict

check: lint test

debug-task:
	$(OP_RUN) mix debug_task $(ARGS)
