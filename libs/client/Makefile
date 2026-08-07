.DEFAULT_GOAL := help
.PHONY: help install test test-coverage lint format dev dev-hot build build-lib clean serve preview check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

HELP_TARGETS := help install test test-coverage lint format dev-build-watch dev-hot build build-lib build-standalone clean serve preview check
HELP_help := Display this help message
HELP_install := Install project dependencies
HELP_test := Run test suite
HELP_test-coverage := Run tests with coverage
HELP_lint := Run linters and code formatters
HELP_format := Format code with biome
HELP_dev-build-watch := Watch and build in development mode
HELP_dev-hot := Start development server with hot reload
HELP_build := Build the project for production
HELP_build-lib := Build the project as a library
HELP_build-standalone := Build standalone bundle (React bundled) for Cloudflare Pages
HELP_clean := Clean build artifacts and temporary files
HELP_serve := Serve production build
HELP_preview := Preview production build
HELP_check := Run all checks (lint + test)

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-20s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	npm install

test: build
	yarn vitest run

test-coverage: build
	yarn vitest run --coverage

lint:
	yarn biome check .

format:
	yarn biome check --write .

dev:
	yarn vite

dev-build-watch:
	yarn vite build --mode development --watch

dev-hot:
	yarn vite --mode development

build:
	$(MAKE) clean
	yarn rescript build

build-lib:
	$(MAKE) clean
	yarn vite build --mode library

build-standalone:
	$(MAKE) clean
	yarn rescript build
	yarn vite build --config vite.config.standalone.ts

clean:
	rm -rf dist

serve:
	yarn vite preview --port 5173 --host

preview:
	yarn vite preview

publish:
	$(MAKE) build-lib
	npm publish

check: lint
