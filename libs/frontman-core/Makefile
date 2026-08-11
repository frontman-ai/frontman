.DEFAULT_GOAL := help
.PHONY: help build test test-watch test-coverage lint format clean

HELP_TARGETS := help build test test-watch test-coverage lint format clean
HELP_help := Display this help message
HELP_build := Build ReScript
HELP_test := Run tests
HELP_test-watch := Run tests in watch mode
HELP_test-coverage := Run tests with coverage
HELP_lint := Check formatting
HELP_format := Format code
HELP_clean := Clean build artifacts

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

build:
	yarn rescript build

test: build
	yarn vitest run

test-watch:
	yarn vitest

test-coverage: build
	yarn vitest run --coverage

lint:
	yarn rescript format --check

format:
	yarn rescript format

clean:
	yarn rescript clean
