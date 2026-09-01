.DEFAULT_GOAL := help
.PHONY: help install build clean export-schemas check-schemas schema-compatibility schema-compatibility-test mcp-verify mcp-property mcp-conformance

HELP_TARGETS := help install build clean export-schemas check-schemas schema-compatibility schema-compatibility-test mcp-verify mcp-property mcp-conformance
HELP_help := Display this help message
HELP_install := Install immutable workspace dependencies
HELP_build := Build ReScript
HELP_clean := Clean build artifacts
HELP_export-schemas := Export Sury schemas to JSON Schema files
HELP_check-schemas := Verify committed schemas are up to date
HELP_schema-compatibility := Check generated schemas for breaking changes
HELP_schema-compatibility-test := Test protocol schema compatibility rules
HELP_mcp-verify := Verify the MCP oracle and normative traceability offline
HELP_mcp-property := Run deterministic MCP differential property tests
HELP_mcp-conformance := Run the pinned official MCP conformance scenarios

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn install --immutable

build:
	yarn rescript build

clean:
	yarn rescript clean

export-schemas: build
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; node scripts/ExportSchemas.res.mjs "$$tmp/raw.json"; node scripts/CompactSchemas.mjs "$$tmp/raw.json" "$$tmp/schemas"; rm -rf schemas/mcp schemas/jsonrpc schemas/relay; find schemas/acp -mindepth 1 -maxdepth 1 ! -name upstream -exec rm -rf {} +; rm -f schemas/generated.json; cp "$$tmp/schemas/generated.json" schemas/generated.json; cp -R "$$tmp/schemas/mcp" schemas/mcp; cp -R "$$tmp/schemas/jsonrpc" schemas/jsonrpc; cp "$$tmp/schemas/acp/"*.json schemas/acp/

check-schemas: build
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; node scripts/ExportSchemas.res.mjs "$$tmp/raw.json"; node scripts/CompactSchemas.mjs "$$tmp/raw.json" "$$tmp/schemas"; diff -u "$$tmp/schemas/generated.json" schemas/generated.json; diff -ru --exclude=upstream "$$tmp/schemas/acp" schemas/acp; diff -ru "$$tmp/schemas/mcp" schemas/mcp; diff -ru "$$tmp/schemas/jsonrpc" schemas/jsonrpc

schema-compatibility: schema-compatibility-test
	node scripts/CheckSchemaCompatibility.mjs

schema-compatibility-test: build
	node --test test/CheckSchemaCompatibility.test.mjs test/CompactSchemas.test.mjs

mcp-verify:
	node --test test/VerifyMcp*.test.mjs
	node scripts/VerifyMcpOracle.mjs
	node scripts/VerifyMcpTraceability.mjs

mcp-property:
	node scripts/VerifyMcpOracle.mjs
	node --test test/VerifyMcpProperty.test.mjs

mcp-conformance:
	$(MAKE) -C ../.. build
	node scripts/VerifyMcpOracle.mjs
	node --test ../../test/mcp-conformance/mcp-conformance.test.mjs
