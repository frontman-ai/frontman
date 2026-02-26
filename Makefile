# Frontman Monorepo Makefile
#
# Usage: make [target]
# Run 'make' or 'make help' to see available commands

.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

# Remote development config
# DEVPOD_SERVER is resolved from .env via `op run` (1Password CLI)
# Usage: op run --env-file=.env -- make <target>
DEVPOD_USER ?= root

define require_devpod_server
	@if [ -z "$(DEVPOD_SERVER)" ]; then \
		printf "$(YELLOW)Error: DEVPOD_SERVER is not set. Run via: op run --env-file=.env -- make $(1)$(RESET)\n"; \
		exit 1; \
	fi
endef

.PHONY: help dev dev-client dev-server dev-nextjs dev-extension dev-marketing dev-dogfooding \
        install build rescript-watch rescript-build clean test lint \
        e2e e2e-nextjs e2e-astro e2e-vite \
        ssl-setup tunnel \
        worktree-create worktree-create-from worktree-list worktree-remove worktree-clean \
        worktree-status worktree-devpod worktree-urls worktree-hosts worktree-register worktree-registry \
        publish publish-astro publish-vite publish-nextjs publish-swarm-ai release \
        kill-all-processes open-dogfooding pull-webapi debug-task

help: ## Display available commands
	@printf "$(CYAN)Frontman Monorepo$(RESET)\n"
	@echo ""
	@printf "$(CYAN)Development:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## DEV_START$$/{found=1; next} /^## DEV_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)Build & Quality:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## BUILD_START$$/{found=1; next} /^## BUILD_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)SSL & Networking:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## SSL_START$$/{found=1; next} /^## SSL_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)Worktree Management:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## WT_START$$/{found=1; next} /^## WT_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)Release:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## REL_START$$/{found=1; next} /^## REL_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)E2E Tests:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## E2E_START$$/{found=1; next} /^## E2E_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(CYAN)Utilities:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## UTIL_START$$/{found=1; next} /^## UTIL_END$$/{found=0} found && /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ============================================================================
# Development
# ============================================================================
## DEV_START

dev: ## Start all core services (client + server + nextjs)
	@printf "$(YELLOW)Starting all services via mprocs...$(RESET)\n"
	mprocs --config mprocs.yml

dev-client: ## Start development server for client app
	@printf "$(YELLOW)Starting client dev server...$(RESET)\n"
	cd libs/client && $(MAKE) dev

dev-server: ## Start development server for server app
	@printf "$(YELLOW)Starting server dev server...$(RESET)\n"
	cd apps/frontman_server && $(MAKE) dev

dev-nextjs: ## Start development server for Next.js test site
	@printf "$(YELLOW)Starting Next.js dev server...$(RESET)\n"
	cd test/sites/blog-starter && $(MAKE) dev

dev-extension: ## Start development server for Chrome extension
	@printf "$(YELLOW)Starting Chrome extension dev server...$(RESET)\n"
	cd apps/chrome-extension && $(MAKE) dev

dev-marketing: ## Start development server for marketing site
	@printf "$(YELLOW)Starting marketing dev server...$(RESET)\n"
	cd apps/marketing && $(MAKE) dev

dev-dogfooding: ## Start development server for dogfooding app
	@printf "$(YELLOW)Starting dogfooding dev server...$(RESET)\n"
	cd apps/dogfooding && npm install && $(MAKE) dev

## DEV_END

# ============================================================================
# Build & Quality
# ============================================================================
## BUILD_START

install: ## Install dependencies
	@printf "$(YELLOW)Installing dependencies...$(RESET)\n"
	yarn install

build: ## Build ReScript project
	@printf "$(YELLOW)Building ReScript project...$(RESET)\n"
	yarn rescript

rescript-watch: ## Watch and rebuild ReScript on changes
	@printf "$(YELLOW)Starting ReScript watch mode...$(RESET)\n"
	yarn rescript watch
rescript-build: ## Builds rescript
	@printf "$(YELLOW)Starting ReScript build mode...$(RESET)\n"
	yarn rescript build
clean: ## Clean build artifacts
	@printf "$(YELLOW)Cleaning build artifacts...$(RESET)\n"
	yarn rescript clean

test: ## Run tests
	# Add test commands here

lint: ## Run linters
	# Add lint commands here

## BUILD_END

# ============================================================================
# E2E Tests
# ============================================================================
## E2E_START

e2e: ## Run all e2e tests (loads secrets from test/e2e/.env)
	@printf "$(YELLOW)Running all e2e tests...$(RESET)\n"
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run

e2e-nextjs: ## Run Next.js e2e test
	@printf "$(YELLOW)Running Next.js e2e test...$(RESET)\n"
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run tests/nextjs.test.ts

e2e-astro: ## Run Astro e2e test
	@printf "$(YELLOW)Running Astro e2e test...$(RESET)\n"
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run tests/astro.test.ts

e2e-vite: ## Run Vite e2e test
	@printf "$(YELLOW)Running Vite e2e test...$(RESET)\n"
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run tests/vite.test.ts

## E2E_END

# ============================================================================
# SSL & Networking
# ============================================================================
## SSL_START

ssl-setup: ## Setup local SSL certificates using mkcert
	@printf "$(YELLOW)Setting up SSL certificates...$(RESET)\n"
	@mkdir -p .certs
	mkcert -install
	cd .certs && mkcert frontman.local localhost 127.0.0.1 ::1
	mv .certs/frontman.local+3.pem .certs/frontman.local.pem
	mv .certs/frontman.local+3-key.pem .certs/frontman.local-key.pem
	sudo sh -c 'grep -q frontman.local /etc/hosts || echo "127.0.0.1 frontman.local" >> /etc/hosts'

tunnel: ## Start SSH tunnel to DevPod server (fallback if dnsmasq not configured)
	$(call require_devpod_server,tunnel)
	@printf "$(YELLOW)Starting SSH tunnel to $(DEVPOD_USER)@$(DEVPOD_SERVER)$(RESET)\n"
	@echo "  Local :8080 → Remote :80 (HTTP)"
	@echo "  Local :8443 → Remote :443 (HTTPS)"
	@echo ""
	@echo "NOTE: With dnsmasq configured, you don't need this tunnel."
	@echo "Press Ctrl+C to stop the tunnel"
	ssh -L 8080:localhost:80 -L 8443:localhost:443 $(DEVPOD_USER)@$(DEVPOD_SERVER) -N

## SSL_END

# ============================================================================
# Worktree Management
# ============================================================================
## WT_START

worktree-create: ## Create a new worktree (BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make worktree-create BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
	@if git show-ref --verify --quiet refs/heads/$(BRANCH); then \
		printf "$(YELLOW)Error: Branch '$(BRANCH)' already exists locally$(RESET)\n"; \
		echo "Use 'make worktree-create-from BRANCH=$(BRANCH)' to create a worktree from it"; \
		exit 1; \
	fi
	@printf "$(YELLOW)Creating worktree for new branch: $(BRANCH)$(RESET)\n"
	@mkdir -p .worktrees
	@git worktree add .worktrees/$(BRANCH) -b $(BRANCH)
	@mkdir -p .worktrees/$(BRANCH)/.claude/projects .worktrees/$(BRANCH)/.claude/plans .worktrees/$(BRANCH)/.claude/todos
	@touch .worktrees/$(BRANCH)/.claude/history.jsonl
	@printf "$(GREEN)Worktree created at: .worktrees/$(BRANCH)$(RESET)\n"
	@echo "Next steps:"
	@echo "  1. cd .worktrees/$(BRANCH)"
	@echo "  2. make install"

worktree-create-from: ## Create worktree from existing branch (BRANCH=name)
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required$(RESET)\n"; \
		echo "Usage: make worktree-create-from BRANCH=origin/feature-name"; \
		exit 1; \
	fi
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|^origin/||'); \
	printf "$(YELLOW)Creating worktree from: $(BRANCH) as $$WORKTREE_NAME$(RESET)\n"; \
	mkdir -p .worktrees; \
	git worktree add .worktrees/$$WORKTREE_NAME $(BRANCH); \
	mkdir -p .worktrees/$$WORKTREE_NAME/.claude/projects .worktrees/$$WORKTREE_NAME/.claude/plans .worktrees/$$WORKTREE_NAME/.claude/todos; \
	touch .worktrees/$$WORKTREE_NAME/.claude/history.jsonl; \
	printf "$(GREEN)Worktree created at: .worktrees/$$WORKTREE_NAME$(RESET)\n"; \
	echo "Next steps:"; \
	echo "  1. cd .worktrees/$$WORKTREE_NAME"; \
	echo "  2. make install"

worktree-list: ## List all worktrees
	@printf "$(CYAN)Active worktrees:$(RESET)\n"
	@git worktree list

worktree-remove: ## Remove a worktree (BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make worktree-remove BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
	@if [ ! -d ".worktrees/$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: Worktree '.worktrees/$(BRANCH)' does not exist$(RESET)\n"; \
		exit 1; \
	fi
	@printf "$(YELLOW)Removing worktree: $(BRANCH)$(RESET)\n"
	@if git -C .worktrees/$(BRANCH) diff --quiet && git -C .worktrees/$(BRANCH) diff --cached --quiet; then \
		git worktree remove .worktrees/$(BRANCH); \
		printf "$(GREEN)Worktree removed$(RESET)\n"; \
	else \
		printf "$(YELLOW)Error: Worktree has uncommitted changes$(RESET)\n"; \
		echo "Commit or stash changes first, or force remove with:"; \
		echo "  git worktree remove --force .worktrees/$(BRANCH)"; \
		exit 1; \
	fi

worktree-clean: ## Remove all stale worktrees
	@printf "$(YELLOW)Cleaning stale worktrees...$(RESET)\n"
	@git worktree prune
	@printf "$(GREEN)Done$(RESET)\n"

worktree-status: ## Show status of all worktrees
	@printf "$(CYAN)Worktree Status:$(RESET)\n"
	@echo ""
	@if [ ! -d ".worktrees" ] || [ -z "$$(ls -A .worktrees 2>/dev/null)" ]; then \
		echo "No worktrees found in .worktrees/"; \
	else \
		for wt in .worktrees/*; do \
			if [ -d "$$wt" ]; then \
				branch=$$(git -C "$$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
				printf "$(GREEN)$$(basename $$wt)$(RESET) ($$branch):\n"; \
				git -C "$$wt" status -s || true; \
				echo ""; \
			fi \
		done; \
	fi

worktree-devpod: ## Create worktree + push + DevPod workspace (BRANCH=name)
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make worktree-devpod BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
	@if ! command -v devpod >/dev/null 2>&1; then \
		printf "$(YELLOW)Error: devpod is not installed. Install with: brew install devpod$(RESET)\n"; \
		exit 1; \
	fi
	@printf "$(YELLOW)==> Creating worktree for: $(BRANCH)$(RESET)\n"
	@$(MAKE) worktree-create BRANCH=$(BRANCH)
	@echo ""
	@printf "$(YELLOW)==> Pushing branch to origin...$(RESET)\n"
	@cd .worktrees/$(BRANCH) && git push -u origin $(BRANCH)
	@echo ""
	@printf "$(YELLOW)==> Creating DevPod workspace on remote server...$(RESET)\n"
	@devpod up . --branch $(BRANCH) --id $(BRANCH)
	@echo ""
	@# Secrets are now resolved via 1Password (op run) from .dev.env — no manual copying needed
	@printf "$(GREEN)  Secrets resolved via 1Password (op run) — ensure 1Password CLI is configured on devpod$(RESET)\n"
	@echo ""
	@printf "$(GREEN)==> Done!$(RESET)\n"
	@echo ""
	@echo "Connect with:"
	@echo "  devpod ssh $(BRANCH)"
	@echo ""
	@echo "Or open in VS Code:"
	@echo "  devpod up $(BRANCH) --ide vscode"

worktree-urls: ## Show URLs for a worktree (BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make worktree-urls BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
	@HASH=$$(printf '%s' "$(BRANCH)" | md5 | cut -c1-4); \
	echo ""; \
	printf "$(CYAN)Worktree: $(BRANCH) ($$HASH)$(RESET)\n"; \
	echo ""; \
	echo "URLs:"; \
	echo "  Next.js:   https://$$HASH.nextjs.frontman.local/frontman"; \
	echo "  Vite:      https://$$HASH.vite.frontman.local"; \
	echo "  Phoenix:   https://$$HASH.api.frontman.local"; \
	echo "  Storybook: https://$$HASH.storybook.frontman.local"; \
	echo ""; \
	echo "Add to /etc/hosts:"; \
	echo "127.0.0.1 $$HASH.nextjs.frontman.local $$HASH.vite.frontman.local $$HASH.api.frontman.local $$HASH.storybook.frontman.local $$HASH.dogfood.frontman.local"

worktree-hosts: ## Generate /etc/hosts entries for all worktrees
	@echo "# Frontman DevPod worktrees"
	@if [ -d ".worktrees" ]; then \
		for wt in .worktrees/*; do \
			if [ -d "$$wt" ]; then \
				name=$$(basename "$$wt"); \
				hash=$$(printf '%s' "$$name" | md5 | cut -c1-4); \
				echo "127.0.0.1 $$hash.nextjs.frontman.local $$hash.vite.frontman.local $$hash.api.frontman.local $$hash.storybook.frontman.local $$hash.dogfood.frontman.local # $$name"; \
			fi \
		done; \
	else \
		echo "# No worktrees found"; \
	fi

worktree-register: ## Register worktree with Caddy (BRANCH= CONTAINER=)
	$(call require_devpod_server,worktree-register)
	@if [ -z "$(BRANCH)" ] || [ -z "$(CONTAINER)" ]; then \
		printf "$(YELLOW)Error: BRANCH and CONTAINER are required.$(RESET)\n"; \
		echo "Usage: make worktree-register BRANCH=feature-name CONTAINER=container-name"; \
		exit 1; \
	fi
	ssh $(DEVPOD_USER)@$(DEVPOD_SERVER) "register-worktree $(BRANCH) $(CONTAINER)"

worktree-registry: ## Show all registered worktrees on the server
	$(call require_devpod_server,worktree-registry)
	@ssh $(DEVPOD_USER)@$(DEVPOD_SERVER) "cat /etc/caddy/worktrees/registry.json 2>/dev/null | jq . || echo 'No worktrees registered'"

## WT_END

# ============================================================================
# Release
# ============================================================================
## REL_START

publish: publish-astro publish-vite publish-nextjs ## Publish all npm packages (pass OTP=<code> for 2FA)

publish-astro: ## Publish @frontman-ai/astro to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-astro && $(MAKE) publish OTP=$(OTP)

publish-vite: ## Publish @frontman-ai/vite to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-vite && $(MAKE) publish OTP=$(OTP)

publish-nextjs: ## Publish @frontman-ai/nextjs to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-nextjs && $(MAKE) publish OTP=$(OTP)

publish-swarm-ai: ## Publish swarm_ai to Hex (dry run by default, HEX_PUBLISH=1 for real)
	cd apps/swarm_ai && $(MAKE) hex-publish HEX_PUBLISH=$(HEX_PUBLISH)

release: ## Create a release PR from pending changesets
	@printf "$(CYAN)Checking release prerequisites...$(RESET)\n"
	@git fetch origin main --quiet
	@LOCAL=$$(git rev-parse HEAD); \
	REMOTE=$$(git rev-parse origin/main); \
	if [ "$$LOCAL" != "$$REMOTE" ]; then \
		printf "$(YELLOW)Error: local HEAD is not up to date with origin/main$(RESET)\n"; \
		echo "Run 'git pull origin main' first"; \
		exit 1; \
	fi
	@CHANGESETS=$$(find .changeset -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l); \
	if [ "$$CHANGESETS" -eq 0 ]; then \
		printf "$(YELLOW)Error: no pending changesets found$(RESET)\n"; \
		echo "Add changesets with 'yarn changeset' before releasing"; \
		exit 1; \
	fi; \
	printf "$(GREEN)Found $$CHANGESETS pending changeset(s)$(RESET)\n"
	@printf "$(YELLOW)Triggering release workflow...$(RESET)\n"
	@gh workflow run release-pr.yml --ref main
	@printf "$(GREEN)Release workflow triggered.$(RESET)\n"
	@echo "Watch for the PR at: https://github.com/frontman-ai/frontman/pulls"

## REL_END

# ============================================================================
# Utilities
# ============================================================================
## UTIL_START

kill-all-processes: ## Kill all running make dev processes
	ps aux | grep "make dev" | awk -F ' ' '{print $$2}' | xargs kill

open-dogfooding: ## Open dogfooding app in browser
	open -n -a "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123

pull-webapi: ## Pull latest experimental-rescript-webapi subtree
	git subtree pull --prefix libs/experimental-rescript-webapi git@github.com:itayadler/experimental-rescript-webapi.git main --squash

debug-task: ## Debug task interactions (ARGS="list" or ARGS="show ...")
	cd apps/frontman_server && $(MAKE) debug-task ARGS="$(ARGS)"

## UTIL_END
