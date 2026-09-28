.DEFAULT_GOAL := help
.PHONY: help install dev build preview type-check clean

HELP_TARGETS := help install dev build preview type-check clean
HELP_help := Display available commands
HELP_install := Install dependencies
HELP_dev := Start development server
HELP_build := Build for production (runs vue-tsc first)
HELP_preview := Preview production build
HELP_type-check := Run vue-tsc type checking
HELP_clean := Clean build artifacts

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn install

dev:
	yarn dev

build:
	yarn build

preview:
	yarn preview

type-check:
	yarn type-check

clean:
	rm -rf dist node_modules/.vite
