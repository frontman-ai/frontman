




.DEFAULT_GOAL := help
.PHONY: help install test test-coverage format lint build clean check precommit credo hex-publish

SHELL := /bin/bash

HELP_TARGETS := help install test test-coverage format lint build clean precommit credo check hex-publish
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_test := Run test suite
HELP_test-coverage := Run tests with coverage report
HELP_format := Auto-format Elixir files
HELP_lint := Run formatter and static analysis
HELP_build := Compile the project
HELP_clean := Clean build artifacts and dependencies
HELP_precommit := Run precommit checks (compile, format, credo, test)
HELP_credo := Run Credo static analysis
HELP_check := Run all checks (lint + test)
HELP_hex-publish := Publish package to Hex (dry run by default, use HEX_PUBLISH=1 for real)

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	mix deps.get

test:
	mix test

test-coverage:
	MIX_ENV=test mix coveralls.cobertura

format:
	mix format

lint:
	mix format --check-formatted
	mix credo --strict --ignore-checks ModuleDoc

build:
	mix compile

clean:
	rm -rf _build deps

precommit:
	mix compile --warnings-as-errors --all-warnings
	mix deps.unlock --unused
	mix format
	mix credo --strict --ignore-checks ModuleDoc
	mix test

credo:
	mix credo --strict --ignore-checks ModuleDoc

check: lint test

hex-publish:
	@if [ "$(HEX_PUBLISH)" = "1" ]; then \
		mix hex.publish; \
	else \
		mix hex.build; \
	fi
