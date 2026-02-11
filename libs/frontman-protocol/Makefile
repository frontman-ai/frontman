.DEFAULT_GOAL := help
.PHONY: help build clean export-schemas check-schemas

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript
	yarn rescript build

clean: ## Clean build artifacts
	yarn rescript clean

export-schemas: build ## Export Sury schemas to JSON Schema files
	node scripts/ExportSchemas.res.mjs

check-schemas: export-schemas ## Verify committed schemas are up to date
	git diff --exit-code schemas/ || (echo "Schemas out of date. Run 'make export-schemas' and commit." && exit 1)
