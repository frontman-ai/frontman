.DEFAULT_GOAL := help
.PHONY: help build test test-watch lint format clean publish

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript + bundle with tsup
	yarn build

publish: build ## Build and publish to npm (pass OTP=<code> for 2FA)
	@PKG=$$(node -e "const p=require('./package.json'); console.log(p.name+'@'+p.version)"); \
	if npm view "$$PKG" version >/dev/null 2>&1; then \
		echo "Error: $$PKG already published — bump the version first"; \
		exit 1; \
	fi; \
	npm publish $(if $(OTP),--otp=$(OTP))

test: ## Run tests
	yarn build:rescript
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest

lint: ## Check formatting
	yarn rescript format -check src

format: ## Format code
	yarn rescript format src

clean: ## Clean build artifacts
	yarn rescript clean
	rm -rf dist
