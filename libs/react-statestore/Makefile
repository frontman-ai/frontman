.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage lint dev build clean check publish

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

HELP_TARGETS := help install test test-watch test-coverage lint dev build clean check publish
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_test := Run test suite
HELP_test-watch := Run tests in watch mode
HELP_test-coverage := Run tests with coverage
HELP_lint := Run linters and code formatters
HELP_dev := Start development server with build watch
HELP_build := Build the project for production
HELP_clean := Clean build artifacts and temporary files
HELP_check := Run all checks (lint + test)
HELP_publish := Build and publish to npm (pass OTP=<code> for 2FA)

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-20s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn

test: build
	yarn vitest run

test-watch: build
	yarn vitest

test-coverage: build
	yarn vitest run --coverage

lint:
	yarn rescript format --check

dev: clean
	yarn rescript watch

build: clean
	yarn rescript build

clean:
	yarn rescript clean

check: lint test

publish: build
	@PKG=$$(node -e "const p=require('./package.json'); console.log(p.name+'@'+p.version)"); \
	if npm view "$$PKG" version >/dev/null 2>&1; then \
		echo "Skipping $$PKG — already published"; \
		exit 0; \
	fi; \
	npm publish $(if $(OTP),--otp=$(OTP))
