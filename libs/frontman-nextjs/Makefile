.DEFAULT_GOAL := help
.PHONY: help build test test-watch test-coverage lint format clean publish

HELP_TARGETS := help build publish test test-watch test-coverage test-otel-compat lint format clean
HELP_help := Display this help message
HELP_build := Build ReScript + bundle
HELP_publish := Build and publish to npm (pass OTP=<code> for 2FA)
HELP_test := Run tests
HELP_test-watch := Run tests in watch mode
HELP_test-coverage := Run tests with coverage
HELP_test-otel-compat := Test packed consumers against supported OpenTelemetry SDKs
HELP_lint := Check formatting
HELP_format := Format code
HELP_clean := Clean build artifacts

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

build:
	yarn build

publish: build
	@PKG=$$(node -e "const p=require('./package.json'); console.log(p.name+'@'+p.version)"); \
	if npm view "$$PKG" version >/dev/null 2>&1; then \
		echo "Skipping $$PKG — already published"; \
		exit 0; \
	fi; \
	npm publish $(if $(OTP),--otp=$(OTP))

test: build
	yarn vitest run

.PHONY: test-otel-compat
test-otel-compat: build
	node ../../test/otel-compat/run.mjs

test-watch:
	yarn vitest

test-coverage: build
	yarn vitest run --coverage

lint:
	yarn rescript format --check src test

format:
	yarn rescript format src test

clean:
	yarn rescript clean
