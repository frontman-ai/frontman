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

# Guard: require BRANCH variable
# Usage: $(call require_branch,target-name)
define require_branch
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make $(1) BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
endef

# Resolve BRANCH: use provided value or auto-detect from current git branch.
# Sets BRANCH via $(eval) so downstream shell blocks see the correct value.
# Usage: $(call resolve_branch,target-name)
define resolve_branch
	$(eval _BRANCH_WAS := $(BRANCH))
	$(eval BRANCH := $(if $(BRANCH),$(BRANCH),$(shell git branch --show-current)))
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: Could not detect branch. Pass it explicitly: make $(1) BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
	@if [ -z "$(_BRANCH_WAS)" ]; then \
		printf "$(CYAN)Auto-detected branch: $(BRANCH)$(RESET)\n"; \
	fi
endef

# Run an e2e test file (or all tests if no file given)
# Usage: $(call run_e2e,test-file-or-empty)
define run_e2e
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run $(1)
endef

.PHONY: help

# Print help section: $(1)=section label, $(2)=marker prefix (e.g. DEV → DEV_START/DEV_END)
define print_section
	@echo ""
	@printf "$(CYAN)$(1):$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^## $(2)_START$$/{found=1; next} /^## $(2)_END$$/{found=0} found && /^[a-zA-Z0-9_-]+:.*##/ { printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
endef

help: ## Display available commands
	@printf "$(CYAN)Frontman Monorepo$(RESET)\n"
	$(call print_section,Development,DEV)
	$(call print_section,Build & Quality,BUILD)
	$(call print_section,SSL & Networking,SSL)
	$(call print_section,Worktrees,WT)
	$(call print_section,Infrastructure,INFRA)
	$(call print_section,Release,REL)
	$(call print_section,E2E Tests,E2E)
	$(call print_section,Utilities,UTIL)
	@echo ""

# ============================================================================
# Development
# ============================================================================
## DEV_START
.PHONY: dev dev-client dev-server dev-nextjs dev-marketing dev-dogfooding

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
.PHONY: install build rescript-watch rescript-build clean

install: ## Install dependencies
	@printf "$(YELLOW)Installing dependencies...$(RESET)\n"
	yarn install

build: ## Build ReScript project
	@printf "$(YELLOW)Building ReScript project...$(RESET)\n"
	yarn rescript

rescript-watch: ## Watch and rebuild ReScript on changes
	@printf "$(YELLOW)Starting ReScript watch mode...$(RESET)\n"
	yarn rescript watch

rescript-build: ## Build ReScript project (one-shot)
	@printf "$(YELLOW)Starting ReScript build...$(RESET)\n"
	yarn rescript build

clean: ## Clean ReScript build artifacts
	@printf "$(YELLOW)Cleaning build artifacts...$(RESET)\n"
	yarn rescript clean

## BUILD_END

# ============================================================================
# E2E Tests
# ============================================================================
## E2E_START
.PHONY: e2e e2e-nextjs e2e-astro e2e-vite e2e-vue-vite

e2e: ## Run all e2e tests (loads secrets from test/e2e/.env)
	@printf "$(YELLOW)Running all e2e tests...$(RESET)\n"
	$(call run_e2e)

e2e-nextjs: ## Run Next.js e2e test
	@printf "$(YELLOW)Running Next.js e2e test...$(RESET)\n"
	$(call run_e2e,tests/nextjs.test.ts)

e2e-astro: ## Run Astro e2e test
	@printf "$(YELLOW)Running Astro e2e test...$(RESET)\n"
	$(call run_e2e,tests/astro.test.ts)

e2e-vite: ## Run Vite e2e test
	@printf "$(YELLOW)Running Vite e2e test...$(RESET)\n"
	$(call run_e2e,tests/vite.test.ts)

e2e-vue-vite: ## Run Vue + Vite e2e test
	@printf "$(YELLOW)Running Vue + Vite e2e test...$(RESET)\n"
	$(call run_e2e,tests/vue-vite.test.ts)

## E2E_END

# ============================================================================
# SSL & Networking
# ============================================================================
## SSL_START
.PHONY: ssl-setup tunnel

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
# Worktrees
# ============================================================================
#
# Primary commands (use these):
#   make wt                    Dashboard — status, URLs, actions at a glance
#   make wt-new   BRANCH=...   Create containerized worktree
#   make wt-dev   BRANCH=...   Start dev servers (mprocs TUI)
#   make wt-stop  BRANCH=...   Pause (preserves data)
#   make wt-start BRANCH=...   Resume paused worktree
#   make wt-sh    BRANCH=...   Shell into container
#   make wt-rm    BRANCH=...   Full cleanup (pod + volumes + worktree)
#   make wt-gc                 Remove worktrees for branches merged into main
#   make wt-urls  BRANCH=...   Show service URLs
#   make wt-logs  BRANCH=...   Tail container logs
#
# All BRANCH= args auto-detect from current git branch when omitted.
#

# Shared variables for containerized worktrees
CADDY_CONTAINER := frontman-caddy
DEV_IMAGE := frontman-dev:latest

# Env vars passed to bin/ scripts so they can compute hashes portably
export MD5CMD := $(shell if command -v md5sum >/dev/null 2>&1; then echo 'md5sum | cut -c1-4'; else echo 'md5 | cut -c1-4'; fi)

## WT_START
.PHONY: wt wt-new wt-dev wt-stop wt-start wt-sh wt-rm wt-gc wt-urls wt-logs work

work: ## Set up worktree from GitHub issue or PR (REF=<number|url>)
	@if [ -z "$(REF)" ]; then \
		printf "$(YELLOW)Usage: make work REF=<issue-number|issue-url|pr-url>$(RESET)\n"; \
		exit 1; \
	fi
	@REF="$(REF)" DEV_IMAGE=$(DEV_IMAGE) bash ./bin/work

wt: ## Dashboard — shows all worktrees, pod status, URLs, and actions
	@bash ./bin/wt-dashboard

wt-new: ## Create containerized worktree (BRANCH=...)
	$(call resolve_branch,wt-new)
	@BRANCH="$(BRANCH)" DEV_IMAGE=$(DEV_IMAGE) \
		bash ./bin/wt-pod-create

wt-dev: ## Start dev servers in container (BRANCH=...)
	$(call resolve_branch,wt-dev)
	@BRANCH="$(BRANCH)" CADDY_CONTAINER=$(CADDY_CONTAINER) \
		bash ./bin/wt-pod-dev

wt-stop: ## Pause worktree pod, preserve volumes (BRANCH=...)
	$(call resolve_branch,wt-stop)
	@POD=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve pod) || exit 1; \
	podman pod stop "$$POD"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Stopped. Resume with: make wt-start BRANCH=$(BRANCH)$(RESET)\n"

wt-start: ## Resume a paused worktree pod (BRANCH=...)
	$(call resolve_branch,wt-start)
	@POD=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve pod) || exit 1; \
	podman pod start "$$POD"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Started. Run: make wt-dev BRANCH=$(BRANCH)$(RESET)\n"

wt-sh: ## Shell into dev container (BRANCH=...)
	$(call resolve_branch,wt-sh)
	@CONTAINER=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve container) || exit 1; \
	podman exec -it -w /workspaces/frontman "$$CONTAINER" bash

wt-rm: ## Full cleanup: pod + volumes + worktree (BRANCH=...)
	$(call resolve_branch,wt-rm)
	@BRANCH="$(BRANCH)" bash ./bin/wt-pod-remove

wt-gc: ## Remove worktrees whose branches are merged into main
	@bash ./bin/wt-gc

wt-urls: ## Show service URLs for a worktree (BRANCH=...)
	$(call resolve_branch,wt-urls)
	@HASH=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve hash); \
	echo ""; \
	printf "$(CYAN)$(BRANCH) ($$HASH)$(RESET)\n"; \
	echo ""; \
	printf "  $(GREEN)Phoenix$(RESET)     https://$$HASH.api.frontman.local\n"; \
	printf "  $(GREEN)Vite$(RESET)        https://$$HASH.vite.frontman.local\n"; \
	printf "  $(GREEN)Next.js$(RESET)     https://$$HASH.nextjs.frontman.local/frontman\n"; \
	printf "  $(GREEN)Storybook$(RESET)   https://$$HASH.storybook.frontman.local\n"; \
	printf "  $(GREEN)Dogfood$(RESET)     https://$$HASH.dogfood.frontman.local\n"; \
	printf "  $(GREEN)Marketing$(RESET)   https://$$HASH.marketing.frontman.local\n"; \
	echo ""

wt-logs: ## Tail dev container logs (BRANCH=...)
	$(call resolve_branch,wt-logs)
	@CONTAINER=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve container) || exit 1; \
	podman logs -f "$$CONTAINER"

## WT_END

# ============================================================================
# Infrastructure
# ============================================================================
## INFRA_START
.PHONY: infra-up infra-down infra-build

infra-up: ## One-time setup: dev image, Caddy, dnsmasq
	@printf "$(CYAN)Setting up containerized worktree infrastructure...$(RESET)\n"
	@echo ""
	@printf "$(YELLOW)Building dev image: $(DEV_IMAGE)$(RESET)\n"
	@podman build -t $(DEV_IMAGE) -f .devcontainer/Dockerfile .devcontainer/
	@echo ""
	@if ! podman container inspect $(CADDY_CONTAINER) &>/dev/null; then \
		printf "$(YELLOW)Starting Caddy reverse proxy (host network)...$(RESET)\n"; \
		mkdir -p infra/local; \
		printf ':9999 {\n    respond "No worktree pods running" 503\n}\n' > infra/local/Caddyfile; \
		podman run -d \
			--name $(CADDY_CONTAINER) \
			--network host \
			-v "$$(pwd)/infra/local/Caddyfile:/etc/caddy/Caddyfile:ro" \
			-v frontman-caddy-data:/data \
			-v frontman-caddy-config:/config \
			docker.io/library/caddy:2-alpine; \
	else \
		printf "$(GREEN)Caddy container already exists$(RESET)\n"; \
		podman start $(CADDY_CONTAINER) 2>/dev/null || true; \
	fi
	@echo ""
	@if command -v dnsmasq &>/dev/null && [ -f /etc/dnsmasq.d/frontman.conf ]; then \
		printf "$(GREEN)dnsmasq: configured$(RESET)\n"; \
	else \
		printf "$(YELLOW)dnsmasq: not configured — run: sudo ./infra/local/dnsmasq-setup.sh$(RESET)\n"; \
	fi
	@echo ""
	@printf "$(GREEN)Infrastructure ready!$(RESET)\n"

infra-down: ## Tear down all pods, volumes, and Caddy
	@printf "$(YELLOW)Tearing down infrastructure...$(RESET)\n"
	@PODS=$$(podman pod ls --format '{{.Name}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -n "$$PODS" ]; then \
		for POD in $$PODS; do printf "  Removing $$POD...\n"; podman pod rm -f "$$POD" 2>/dev/null || true; done; \
	fi
	@VOLS=$$(podman volume ls --format '{{.Name}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -n "$$VOLS" ]; then echo "$$VOLS" | xargs podman volume rm -f 2>/dev/null || true; fi
	@podman rm -f $(CADDY_CONTAINER) 2>/dev/null || true
	@podman volume rm -f frontman-caddy-data frontman-caddy-config 2>/dev/null || true
	@printf "$(GREEN)Infrastructure torn down$(RESET)\n"
	@echo "Note: git worktrees and dnsmasq config are preserved"

infra-build: ## Rebuild the frontman-dev container image
	@podman build -t $(DEV_IMAGE) -f .devcontainer/Dockerfile .devcontainer/

## INFRA_END

# ============================================================================
# Worktree Internals (not shown in help — use wt-* commands above)
# ============================================================================
.PHONY: worktree-create worktree-list worktree-remove worktree-clean \
        worktree-register worktree-registry

# Plain worktree management (without containers)
# Auto-detects whether to create a new branch or check out an existing one.
worktree-create:
	$(call require_branch,worktree-create)
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|^origin/||'); \
	mkdir -p .worktrees; \
	if git show-ref --verify --quiet "refs/heads/$$WORKTREE_NAME" || \
	   git show-ref --verify --quiet "refs/remotes/origin/$$WORKTREE_NAME" || \
	   git show-ref --verify --quiet "refs/remotes/$(BRANCH)"; then \
		git worktree add ".worktrees/$$WORKTREE_NAME" $(BRANCH); \
	else \
		git worktree add ".worktrees/$$WORKTREE_NAME" -b "$$WORKTREE_NAME"; \
	fi; \
	mkdir -p ".worktrees/$$WORKTREE_NAME/.claude/projects" ".worktrees/$$WORKTREE_NAME/.claude/plans" ".worktrees/$$WORKTREE_NAME/.claude/todos"; \
	touch ".worktrees/$$WORKTREE_NAME/.claude/history.jsonl"; \
	printf "$(GREEN)Worktree created at: .worktrees/$$WORKTREE_NAME$(RESET)\n"

worktree-list:
	@git worktree list

worktree-remove:
	$(call require_branch,worktree-remove)
	@if [ ! -d ".worktrees/$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: Worktree '.worktrees/$(BRANCH)' does not exist$(RESET)\n"; exit 1; \
	fi
	@if git -C .worktrees/$(BRANCH) diff --quiet && git -C .worktrees/$(BRANCH) diff --cached --quiet; then \
		git worktree remove .worktrees/$(BRANCH); printf "$(GREEN)Worktree removed$(RESET)\n"; \
	else \
		printf "$(YELLOW)Error: Uncommitted changes. Force: git worktree remove --force .worktrees/$(BRANCH)$(RESET)\n"; exit 1; \
	fi

worktree-clean:
	@git worktree prune && printf "$(GREEN)Done$(RESET)\n"

worktree-register:
	$(call require_devpod_server,worktree-register)
	@if [ -z "$(BRANCH)" ] || [ -z "$(CONTAINER)" ]; then \
		printf "$(YELLOW)Error: BRANCH and CONTAINER required$(RESET)\n"; exit 1; \
	fi
	ssh $(DEVPOD_USER)@$(DEVPOD_SERVER) "register-worktree $(BRANCH) $(CONTAINER)"

worktree-registry:
	$(call require_devpod_server,worktree-registry)
	@ssh $(DEVPOD_USER)@$(DEVPOD_SERVER) "cat /etc/caddy/worktrees/registry.json 2>/dev/null | jq . || echo 'No worktrees registered'"

# ============================================================================
# Release
# ============================================================================
## REL_START
.PHONY: publish publish-astro publish-vite publish-nextjs publish-react-statestore publish-swarm-ai release package-wordpress-plugin test-wordpress-core-tools

publish: publish-astro publish-vite publish-nextjs publish-react-statestore ## Publish all npm packages (pass OTP=<code> for 2FA)

publish-astro: ## Publish @frontman-ai/astro to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-astro && $(MAKE) publish OTP=$(OTP)

publish-vite: ## Publish @frontman-ai/vite to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-vite && $(MAKE) publish OTP=$(OTP)

publish-nextjs: ## Publish @frontman-ai/nextjs to npm (pass OTP=<code> for 2FA)
	cd libs/frontman-nextjs && $(MAKE) publish OTP=$(OTP)

publish-react-statestore: ## Publish @frontman-ai/react-statestore to npm (pass OTP=<code> for 2FA)
	cd libs/react-statestore && $(MAKE) publish OTP=$(OTP)

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

package-wordpress-plugin: ## Build WordPress ZIP and WordPress.org bundle
	@VERSION=$(VERSION) bash ./scripts/package-wordpress-plugin.sh

test-wordpress-core-tools: ## Run PHP tests for WordPress core tool implementations
	@php libs/frontman-wordpress/tests/CoreToolsTest.php
	@php libs/frontman-wordpress/tests/MutationSnapshotsTest.php
	@php libs/frontman-wordpress/tests/RouterTest.php

## REL_END

# ============================================================================
# Utilities
# ============================================================================
## UTIL_START
.PHONY: kill-all-processes open-dogfooding pull-webapi debug-task pr-summary push

kill-all-processes: ## Kill all running make dev processes
	@ps aux | grep "[m]ake dev" | awk '{print $$2}' | xargs -r kill 2>/dev/null || true

open-dogfooding: ## Open dogfooding app in browser (isolated Chrome profile)
	@if [ "$$(uname)" = "Darwin" ]; then \
		open -n -a "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
			--args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123; \
	elif command -v google-chrome >/dev/null 2>&1; then \
		google-chrome --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123; \
	elif command -v google-chrome-stable >/dev/null 2>&1; then \
		google-chrome-stable --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123; \
	elif command -v chromium-browser >/dev/null 2>&1; then \
		chromium-browser --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		printf "$(YELLOW)No Chrome found — opening with default browser (--disable-web-security not applied)$(RESET)\n"; \
		xdg-open http://localhost:6123; \
	else \
		printf "$(YELLOW)Error: No supported browser found. Open http://localhost:6123 manually.$(RESET)\n"; \
		exit 1; \
	fi

pull-webapi: ## Pull latest experimental-rescript-webapi subtree
	git subtree pull --prefix libs/experimental-rescript-webapi git@github.com:itayadler/experimental-rescript-webapi.git main --squash

debug-task: ## Debug task interactions (ARGS="list" or ARGS="show ...")
	cd apps/frontman_server && $(MAKE) debug-task ARGS="$(ARGS)"

# AGD render-summary script lives in the AGD repo
AGD_RENDER_SUMMARY := $(HOME)/dev/agd/scripts/render-summary.py

pr-summary: ## Post AGD usage summary as a comment on the current branch's PR
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" = "HEAD" ] || [ "$$BRANCH" = "main" ]; then \
		printf "$(YELLOW)Error: must be on a feature branch (current: $$BRANCH)$(RESET)\n"; \
		exit 1; \
	fi; \
	PR=$$(gh pr view --json number -q .number 2>/dev/null); \
	if [ -z "$$PR" ]; then \
		printf "$(YELLOW)Error: no open PR found for branch '$$BRANCH'$(RESET)\n"; \
		exit 1; \
	fi; \
	BODY=$$(agd log --branch "$$BRANCH" --format json 2>/dev/null | python3 $(AGD_RENDER_SUMMARY)); \
	if [ -z "$$BODY" ]; then \
		printf "$(CYAN)No AGD traces found for branch '$$BRANCH'$(RESET)\n"; \
		exit 0; \
	fi; \
	REPO=$$(gh repo view --json nameWithOwner -q .nameWithOwner); \
	MARKER="<!-- agd-summary -->"; \
	EXISTING=$$(gh api "repos/$$REPO/issues/$$PR/comments" --paginate -q ".[] | select(.body | startswith(\"$$MARKER\")) | .id" 2>/dev/null | head -1); \
	if [ -n "$$EXISTING" ]; then \
		echo "$$BODY" | gh api "repos/$$REPO/issues/comments/$$EXISTING" -X PATCH --field "body=@-" > /dev/null; \
		printf "$(GREEN)Updated AGD summary on PR #$$PR$(RESET)\n"; \
	else \
		echo "$$BODY" | gh api "repos/$$REPO/issues/$$PR/comments" -X POST --field "body=@-" > /dev/null; \
		printf "$(GREEN)Posted AGD summary on PR #$$PR$(RESET)\n"; \
	fi

push: ## Git push + auto-update PR summary with AGD stats
	@git push
	@$(MAKE) --no-print-directory pr-summary

## UTIL_END
