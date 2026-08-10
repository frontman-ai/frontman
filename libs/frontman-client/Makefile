.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage build clean lint format check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

HELP_TARGETS := help install build dev test test-watch test-coverage lint format check clean
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_build := Build the project
HELP_dev := Build the project in watch mode
HELP_test := Run test suite
HELP_test-watch := Run tests in watch mode
HELP_test-coverage := Run tests with coverage
HELP_lint := Check code formatting
HELP_format := Format code
HELP_check := Run all checks (lint + test)
HELP_clean := Clean build artifacts and temporary files

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn install

build:
	yarn rescript build
dev:
	yarn rescript watch

test: build
	yarn vitest run

test-watch:
	yarn vitest watch

test-coverage: build
	yarn vitest run --coverage

lint:
	yarn rescript format --check

format:
	yarn rescript format

check: lint test

clean:
	yarn rescript clean
