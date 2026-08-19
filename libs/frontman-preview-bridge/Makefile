.DEFAULT_GOAL := help
.PHONY: help compile build test install-browser test-browser format clean

HELP_TARGETS := help compile build test install-browser test-browser format clean
HELP_help := Display this help message
HELP_compile := Build ReScript
HELP_build := Build classic bridge bundle
HELP_test := Run focused tests
HELP_install-browser := Install Chromium for browser tests
HELP_test-browser := Run cross-origin browser integration
HELP_format := Format ReScript source
HELP_clean := Clean build artifacts

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

compile:
	yarn rescript build

build: compile
	yarn vite build

test: build
	yarn vitest run

install-browser:
	yarn playwright install --with-deps chromium

test-browser: build
	node browser-tests/run.mjs

format:
	yarn rescript format src/*.res test/*.res

clean:
	yarn rescript clean
