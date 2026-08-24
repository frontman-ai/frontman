.DEFAULT_GOAL := help
.PHONY: help build test clean export-schemas check-schemas

HELP_TARGETS := help build test clean export-schemas check-schemas
HELP_help := Display this help message
HELP_build := Build ReScript
HELP_test := Run tests
HELP_clean := Clean build artifacts
HELP_export-schemas := Export Sury schemas to JSON Schema files
HELP_check-schemas := Verify committed schemas are up to date

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

build:
	yarn rescript build

test: build
	yarn vitest run

clean:
	yarn rescript clean

export-schemas: build
	node scripts/ExportSchemas.res.mjs

check-schemas: export-schemas
	git diff --exit-code schemas/ || (echo "Schemas out of date. Run 'make export-schemas' and commit." && exit 1)
