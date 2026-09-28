.DEFAULT_GOAL := help
.PHONY: help compile build test format clean

HELP_TARGETS := help compile build test format clean
HELP_help := Display this help message
HELP_compile := Build ReScript
HELP_build := Build classic bridge bundle
HELP_test := Run focused tests
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

format:
	yarn rescript format src/*.res src/*.resi test/*.res

clean:
	yarn rescript clean
