

.DEFAULT_GOAL := help
.PHONY: help install test format lint build release precommit clean

SHELL := /bin/bash

HELP_TARGETS := help install test format lint build release precommit clean
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_test := Run test suite
HELP_format := Auto-format Elixir files
HELP_lint := Run formatter and static analysis
HELP_build := Compile for production
HELP_release := Build production release tarball
HELP_precommit := Run precommit checks
HELP_clean := Clean build artifacts and dependencies

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	mix deps.get

test:
	mix test

format:
	mix format

lint:
	mix format --check-formatted
	mix credo --strict --ignore-checks ModuleDoc

build:
	MIX_ENV=prod mix compile --warnings-as-errors --all-warnings

release: build
	MIX_ENV=prod mix release --overwrite

precommit:
	mix compile --warnings-as-errors --all-warnings
	mix deps.unlock --unused
	mix format
	mix credo --strict --ignore-checks ModuleDoc
	mix test

clean:
	rm -rf _build deps
