.DEFAULT_GOAL := help
.PHONY: help build test test-watch lint format clean publish

HELP_TARGETS := help build publish test test-watch lint format clean
HELP_help := Display this help message
HELP_build := Build ReScript + bundle with tsup
HELP_publish := Build and publish to npm (pass OTP=<code> for 2FA)
HELP_test := Run tests
HELP_test-watch := Run tests in watch mode
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

test-watch:
	yarn vitest

lint:
	yarn rescript format --check

format:
	yarn rescript format

clean:
	yarn rescript clean
