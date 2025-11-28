.DEFAULT_GOAL := help
.PHONY: help build clean

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript
	yarn rescript build

clean: ## Clean build artifacts
	yarn rescript clean
