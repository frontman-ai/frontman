.DEFAULT_GOAL := help
.PHONY: help install build clean export-schemas check-schemas mcp-verify mcp-property

HELP_TARGETS := help install build clean export-schemas check-schemas mcp-verify mcp-property
HELP_help := Display this help message
HELP_install := Install immutable workspace dependencies
HELP_build := Build ReScript
HELP_clean := Clean build artifacts
HELP_export-schemas := Export Sury schemas to JSON Schema files
HELP_check-schemas := Verify committed schemas are up to date
HELP_mcp-verify := Verify the MCP oracle and normative traceability offline
HELP_mcp-property := Run deterministic MCP differential property tests

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn install --immutable

build:
	yarn rescript build

clean:
	yarn rescript clean

export-schemas: build
	node scripts/ExportSchemas.res.mjs

check-schemas: export-schemas
	git diff --exit-code schemas/ || (echo "Schemas out of date. Run 'make export-schemas' and commit." && exit 1)

mcp-verify:
	node --test test/VerifyMcp*.test.mjs
	node scripts/VerifyMcpOracle.mjs
	node scripts/VerifyMcpTraceability.mjs

mcp-property:
	node scripts/VerifyMcpOracle.mjs
	node --test test/VerifyMcpProperty.test.mjs
