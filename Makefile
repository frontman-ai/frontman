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

# Portable MD5 hash — works on both macOS (md5) and Linux (md5sum)
# Usage in shell: $$(echo -n "value" | $(MD5_SHORT))
# Produces a 4-character hex prefix
MD5_SHORT = $(shell if command -v md5sum >/dev/null 2>&1; then echo 'md5sum | cut -c1-4'; else echo 'md5 | cut -c1-4'; fi)

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
	$(call print_section,Worktree Management,WT)
	$(call print_section,Infrastructure (Containerized Worktrees),INFRA)
	$(call print_section,Containerized Worktree Pods,POD)
	$(call print_section,Release,REL)
	$(call print_section,E2E Tests,E2E)
	$(call print_section,Utilities,UTIL)
	@echo ""

# ============================================================================
# Development
# ============================================================================
## DEV_START
.PHONY: dev dev-client dev-server dev-nextjs dev-extension dev-marketing dev-dogfooding

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
.PHONY: e2e e2e-nextjs e2e-astro e2e-vite

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
# Worktree Management
# ============================================================================
## WT_START
.PHONY: worktree-create worktree-create-from worktree-list worktree-remove worktree-clean \
        worktree-status worktree-devpod worktree-urls worktree-hosts worktree-register worktree-registry

worktree-create: ## Create a new worktree (BRANCH=feature-name)
	$(call require_branch,worktree-create)
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
	$(call require_branch,worktree-create-from)
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
	$(call require_branch,worktree-remove)
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
	$(call require_branch,worktree-devpod)
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
	$(call require_branch,worktree-urls)
	@HASH=$$(printf '%s' "$(BRANCH)" | $(MD5_SHORT)); \
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
				hash=$$(printf '%s' "$$name" | $(MD5_SHORT)); \
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
# Infrastructure (Containerized Worktrees)
# ============================================================================
## INFRA_START
.PHONY: infra-up infra-down infra-build infra-status

# Shared variables for containerized worktrees
FRONTMAN_NET := frontman-net
CADDY_CONTAINER := frontman-caddy
DEV_IMAGE := frontman-dev:latest

infra-up: ## One-time setup: network, dev image, Caddy, dnsmasq
	@printf "$(CYAN)Setting up containerized worktree infrastructure...$(RESET)\n"
	@echo ""
	@# Create podman network (ignore if exists)
	@if ! podman network inspect $(FRONTMAN_NET) &>/dev/null; then \
		printf "$(YELLOW)Creating podman network: $(FRONTMAN_NET)$(RESET)\n"; \
		podman network create $(FRONTMAN_NET); \
	else \
		printf "$(GREEN)Network $(FRONTMAN_NET) already exists$(RESET)\n"; \
	fi
	@echo ""
	@# Build dev image
	@printf "$(YELLOW)Building dev image: $(DEV_IMAGE)$(RESET)\n"
	@podman build -t $(DEV_IMAGE) -f .devcontainer/Dockerfile .devcontainer/
	@echo ""
	@# Start Caddy reverse proxy
	@if ! podman container inspect $(CADDY_CONTAINER) &>/dev/null; then \
		printf "$(YELLOW)Starting Caddy reverse proxy...$(RESET)\n"; \
		mkdir -p infra/local; \
		touch infra/local/Caddyfile; \
		echo ':80 { respond "No worktree pods running" 503 }' > infra/local/Caddyfile; \
		podman run -d \
			--name $(CADDY_CONTAINER) \
			--network $(FRONTMAN_NET) \
			-p 80:80 -p 443:443 \
			-v "$$(pwd)/infra/local/Caddyfile:/etc/caddy/Caddyfile:ro" \
			-v frontman-caddy-data:/data \
			-v frontman-caddy-config:/config \
			docker.io/library/caddy:2-alpine; \
	else \
		printf "$(GREEN)Caddy container already exists$(RESET)\n"; \
		podman start $(CADDY_CONTAINER) 2>/dev/null || true; \
	fi
	@echo ""
	@# Check dnsmasq
	@if command -v dnsmasq &>/dev/null && [ -f /etc/dnsmasq.d/frontman.conf ]; then \
		printf "$(GREEN)dnsmasq: configured$(RESET)\n"; \
	else \
		printf "$(YELLOW)dnsmasq: not configured$(RESET)\n"; \
		echo "  Run: sudo ./infra/local/dnsmasq-setup.sh"; \
	fi
	@echo ""
	@printf "$(GREEN)Infrastructure ready!$(RESET)\n"

infra-down: ## Tear down: stop all pods, remove volumes, stop Caddy
	@printf "$(YELLOW)Tearing down containerized worktree infrastructure...$(RESET)\n"
	@echo ""
	@# Warn about running pods
	@PODS=$$(podman pod ls --format '{{.Name}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -n "$$PODS" ]; then \
		printf "$(YELLOW)Stopping worktree pods:$(RESET)\n"; \
		for POD in $$PODS; do \
			printf "  Removing $$POD...\n"; \
			podman pod rm -f "$$POD" 2>/dev/null || true; \
		done; \
	fi
	@# Remove worktree volumes
	@VOLS=$$(podman volume ls --format '{{.Name}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -n "$$VOLS" ]; then \
		printf "$(YELLOW)Removing worktree volumes...$(RESET)\n"; \
		echo "$$VOLS" | xargs podman volume rm -f 2>/dev/null || true; \
	fi
	@# Stop Caddy
	@if podman container inspect $(CADDY_CONTAINER) &>/dev/null; then \
		printf "$(YELLOW)Stopping Caddy...$(RESET)\n"; \
		podman rm -f $(CADDY_CONTAINER) 2>/dev/null || true; \
	fi
	@# Remove Caddy volumes
	@podman volume rm -f frontman-caddy-data frontman-caddy-config 2>/dev/null || true
	@# Remove network
	@if podman network inspect $(FRONTMAN_NET) &>/dev/null; then \
		printf "$(YELLOW)Removing network: $(FRONTMAN_NET)$(RESET)\n"; \
		podman network rm $(FRONTMAN_NET) 2>/dev/null || true; \
	fi
	@echo ""
	@printf "$(GREEN)Infrastructure torn down$(RESET)\n"
	@echo "Note: git worktrees and dnsmasq config are preserved"

infra-build: ## Rebuild the frontman-dev container image
	@printf "$(YELLOW)Rebuilding dev image: $(DEV_IMAGE)$(RESET)\n"
	@podman build -t $(DEV_IMAGE) -f .devcontainer/Dockerfile .devcontainer/

infra-status: ## Show infrastructure status
	@printf "$(CYAN)Infrastructure Status$(RESET)\n"
	@echo ""
	@# Network
	@if podman network inspect $(FRONTMAN_NET) &>/dev/null; then \
		printf "  Network:  $(GREEN)$(FRONTMAN_NET) exists$(RESET)\n"; \
	else \
		printf "  Network:  $(YELLOW)$(FRONTMAN_NET) not found$(RESET)\n"; \
	fi
	@# Caddy
	@if podman container inspect $(CADDY_CONTAINER) &>/dev/null; then \
		STATE=$$(podman container inspect $(CADDY_CONTAINER) --format '{{.State.Status}}' 2>/dev/null); \
		printf "  Caddy:    $(GREEN)$$STATE$(RESET)\n"; \
	else \
		printf "  Caddy:    $(YELLOW)not created$(RESET)\n"; \
	fi
	@# dnsmasq
	@if [ -f /etc/dnsmasq.d/frontman.conf ]; then \
		printf "  dnsmasq:  $(GREEN)configured$(RESET)\n"; \
	else \
		printf "  dnsmasq:  $(YELLOW)not configured$(RESET)\n"; \
	fi
	@# Dev image
	@if podman image inspect $(DEV_IMAGE) &>/dev/null; then \
		printf "  Image:    $(GREEN)$(DEV_IMAGE) built$(RESET)\n"; \
	else \
		printf "  Image:    $(YELLOW)$(DEV_IMAGE) not built$(RESET)\n"; \
	fi
	@echo ""
	@# Pods
	@printf "$(CYAN)Active Worktree Pods$(RESET)\n"
	@PODS=$$(podman pod ls --format '{{.Name}} {{.Status}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -n "$$PODS" ]; then \
		echo "$$PODS" | while read -r POD_LINE; do \
			POD_NAME=$$(echo "$$POD_LINE" | awk '{print $$1}'); \
			POD_STATUS=$$(echo "$$POD_LINE" | cut -d' ' -f2-); \
			HASH=$${POD_NAME#worktree-}; \
			printf "  $(GREEN)$$POD_NAME$(RESET) ($$POD_STATUS)\n"; \
			printf "    Phoenix:   https://$$HASH.api.frontman.local\n"; \
			printf "    Vite:      https://$$HASH.vite.frontman.local\n"; \
			printf "    Next.js:   https://$$HASH.nextjs.frontman.local/frontman\n"; \
			printf "    Storybook: https://$$HASH.storybook.frontman.local\n"; \
			printf "    Marketing: https://$$HASH.marketing.frontman.local\n"; \
			echo ""; \
		done; \
	else \
		echo "  No worktree pods running"; \
	fi
	@echo ""

## INFRA_END

# ============================================================================
# Containerized Worktree Pods
# ============================================================================
## POD_START
.PHONY: worktree-pod-create worktree-pod-dev worktree-pod-attach worktree-pod-stop \
        worktree-pod-start worktree-pod-remove worktree-pod-list worktree-pod-logs

worktree-pod-create: ## Create containerized worktree (BRANCH=feature/x)
	$(call require_branch,worktree-pod-create)
	@# Verify infra is up
	@if ! podman network inspect $(FRONTMAN_NET) &>/dev/null; then \
		printf "$(YELLOW)Error: Infrastructure not set up. Run 'make infra-up' first.$(RESET)\n"; \
		exit 1; \
	fi
	@if ! podman image inspect $(DEV_IMAGE) &>/dev/null; then \
		printf "$(YELLOW)Error: Dev image not built. Run 'make infra-up' first.$(RESET)\n"; \
		exit 1; \
	fi
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	POD_NAME="worktree-$${HASH}"; \
	WT_DIR="$$(pwd)/.worktrees/$(BRANCH)"; \
	printf "$(CYAN)Creating containerized worktree$(RESET)\n"; \
	printf "  Branch: $(BRANCH)\n"; \
	printf "  Hash:   $${HASH}\n"; \
	printf "  Pod:    $${POD_NAME}\n"; \
	echo ""; \
	\
	if podman pod inspect "$${POD_NAME}" &>/dev/null; then \
		printf "$(YELLOW)Pod $${POD_NAME} already exists. Use worktree-pod-start to resume.$(RESET)\n"; \
		exit 1; \
	fi; \
	\
	printf "$(YELLOW)==> Creating git worktree...$(RESET)\n"; \
	mkdir -p .worktrees; \
	if [ -d "$${WT_DIR}" ]; then \
		printf "$(GREEN)Worktree already exists at $${WT_DIR}$(RESET)\n"; \
	elif git show-ref --verify --quiet "refs/heads/$(BRANCH)"; then \
		git worktree add "$${WT_DIR}" "$(BRANCH)"; \
	else \
		git worktree add "$${WT_DIR}" -b "$(BRANCH)"; \
	fi; \
	mkdir -p "$${WT_DIR}/.claude/projects" "$${WT_DIR}/.claude/plans" "$${WT_DIR}/.claude/todos"; \
	touch "$${WT_DIR}/.claude/history.jsonl"; \
	echo ""; \
	\
	printf "$(YELLOW)==> Resolving secrets...$(RESET)\n"; \
	op run --no-masking --env-file=apps/frontman_server/envs/.dev.secrets.env -- env | \
		grep -v '^_=' | grep -v '^SHLVL=' | grep -v '^PWD=' | grep -v '^OLDPWD=' | \
		grep -E '^(WORKOS_|OPENROUTER_|SENTRY_|SECRET_|DATABASE_|PHX_|FRONTMAN_)' \
		> "$${WT_DIR}/.env.secrets.resolved" || true; \
	echo ""; \
	\
	printf "$(YELLOW)==> Creating Podman pod: $${POD_NAME}$(RESET)\n"; \
	podman pod create \
		--name "$${POD_NAME}" \
		--network $(FRONTMAN_NET); \
	echo ""; \
	\
	printf "$(YELLOW)==> Starting PostgreSQL...$(RESET)\n"; \
	podman run -d \
		--pod "$${POD_NAME}" \
		--name "$${POD_NAME}-pg" \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-v "worktree-$${HASH}-pgdata:/var/lib/postgresql/data" \
		docker.io/library/postgres:16; \
	echo ""; \
	\
	printf "$(YELLOW)==> Starting dev container...$(RESET)\n"; \
	podman run -d \
		--pod "$${POD_NAME}" \
		--name "$${POD_NAME}-dev" \
		--user root \
		-e "HOME=/home/vscode" \
		--env-file "$${WT_DIR}/.env.secrets.resolved" \
		-e "WORKTREE_HASH=$${HASH}" \
		-e "WORKTREE_BRANCH=$(BRANCH)" \
		-v "$${WT_DIR}:/workspaces/frontman" \
		-v "worktree-$${HASH}-node-modules:/workspaces/frontman/node_modules" \
		-v "worktree-$${HASH}-mix-build:/workspaces/frontman/apps/frontman_server/_build" \
		-v "worktree-$${HASH}-mix-deps:/workspaces/frontman/apps/frontman_server/deps" \
		$(DEV_IMAGE) \
		sleep infinity; \
	echo ""; \
	\
	printf "$(YELLOW)==> Waiting for PostgreSQL to be ready...$(RESET)\n"; \
	for i in $$(seq 1 30); do \
		if podman exec "$${POD_NAME}-dev" bash -c 'pg_isready -h localhost -U postgres' &>/dev/null; then \
			break; \
		fi; \
		sleep 1; \
	done; \
	echo ""; \
	\
	printf "$(YELLOW)==> Running setup inside container...$(RESET)\n"; \
	podman exec \
		-e "WORKTREE_HASH=$${HASH}" \
		-e "WORKTREE_BRANCH=$(BRANCH)" \
		-w /workspaces/frontman \
		"$${POD_NAME}-dev" \
		bash ./infra/local/worktree-setup.sh; \
	echo ""; \
	\
	printf "$(YELLOW)==> Updating Caddy routes...$(RESET)\n"; \
	bash ./infra/local/caddy-regen.sh; \
	echo ""; \
	\
	printf "$(GREEN)==> Containerized worktree ready!$(RESET)\n"; \
	echo ""; \
	echo "Start development:"; \
	echo "  make worktree-pod-dev BRANCH=$(BRANCH)"; \
	echo ""; \
	echo "URLs:"; \
	echo "  Phoenix:   https://$${HASH}.api.frontman.local"; \
	echo "  Vite:      https://$${HASH}.vite.frontman.local"; \
	echo "  Next.js:   https://$${HASH}.nextjs.frontman.local/frontman"; \
	echo "  Storybook: https://$${HASH}.storybook.frontman.local"

worktree-pod-dev: ## Start mprocs TUI inside container (BRANCH=feature/x)
	$(call require_branch,worktree-pod-dev)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	CONTAINER="worktree-$${HASH}-dev"; \
	if ! podman container inspect "$${CONTAINER}" &>/dev/null; then \
		printf "$(YELLOW)Error: Container $${CONTAINER} not found. Create it first:$(RESET)\n"; \
		echo "  make worktree-pod-create BRANCH=$(BRANCH)"; \
		exit 1; \
	fi; \
	printf "$(CYAN)Checking dependencies in $${CONTAINER}...$(RESET)\n"; \
	NODE_COUNT=$$(podman exec -w /workspaces/frontman "$${CONTAINER}" \
		bash -c 'ls node_modules/ 2>/dev/null | wc -l'); \
	MIX_DEPS=$$(podman exec -w /workspaces/frontman/apps/frontman_server "$${CONTAINER}" \
		bash -c 'ls deps/ 2>/dev/null | wc -l'); \
	if [ "$${NODE_COUNT}" -lt 10 ] || [ "$${MIX_DEPS}" -lt 5 ]; then \
		printf "$(YELLOW)Dependencies missing (node_modules: $${NODE_COUNT}, mix deps: $${MIX_DEPS}). Running setup...$(RESET)\n"; \
		podman exec \
			-e "WORKTREE_HASH=$${HASH}" \
			-e "WORKTREE_BRANCH=$(BRANCH)" \
			-w /workspaces/frontman \
			"$${CONTAINER}" \
			bash ./infra/local/worktree-setup.sh; \
	else \
		printf "$(GREEN)Dependencies OK (node_modules: $${NODE_COUNT}, mix deps: $${MIX_DEPS})$(RESET)\n"; \
	fi; \
	printf "$(CYAN)Starting mprocs in $${CONTAINER}...$(RESET)\n"; \
	podman exec -it -w /workspaces/frontman "$${CONTAINER}" \
		bash -l -c 'eval "$$(mise activate bash)" && exec mprocs --config mprocs.container.yml'

worktree-pod-attach: ## Interactive shell into dev container (BRANCH=feature/x)
	$(call require_branch,worktree-pod-attach)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	CONTAINER="worktree-$${HASH}-dev"; \
	if ! podman container inspect "$${CONTAINER}" &>/dev/null; then \
		printf "$(YELLOW)Error: Container $${CONTAINER} not found$(RESET)\n"; \
		exit 1; \
	fi; \
	podman exec -it -w /workspaces/frontman "$${CONTAINER}" bash

worktree-pod-stop: ## Stop pod, preserve volumes (BRANCH=feature/x)
	$(call require_branch,worktree-pod-stop)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	POD_NAME="worktree-$${HASH}"; \
	if ! podman pod inspect "$${POD_NAME}" &>/dev/null; then \
		printf "$(YELLOW)Error: Pod $${POD_NAME} not found$(RESET)\n"; \
		exit 1; \
	fi; \
	printf "$(YELLOW)Stopping pod: $${POD_NAME}$(RESET)\n"; \
	podman pod stop "$${POD_NAME}"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Pod stopped. Volumes preserved. Resume with: make worktree-pod-start BRANCH=$(BRANCH)$(RESET)\n"

worktree-pod-start: ## Restart a stopped pod (BRANCH=feature/x)
	$(call require_branch,worktree-pod-start)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	POD_NAME="worktree-$${HASH}"; \
	if ! podman pod inspect "$${POD_NAME}" &>/dev/null; then \
		printf "$(YELLOW)Error: Pod $${POD_NAME} not found. Create it first:$(RESET)\n"; \
		echo "  make worktree-pod-create BRANCH=$(BRANCH)"; \
		exit 1; \
	fi; \
	printf "$(YELLOW)Starting pod: $${POD_NAME}$(RESET)\n"; \
	podman pod start "$${POD_NAME}"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Pod started. Run: make worktree-pod-dev BRANCH=$(BRANCH)$(RESET)\n"

worktree-pod-remove: ## Full cleanup: pod, volumes, worktree (BRANCH=feature/x)
	$(call require_branch,worktree-pod-remove)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	POD_NAME="worktree-$${HASH}"; \
	WT_DIR="$$(pwd)/.worktrees/$(BRANCH)"; \
	printf "$(YELLOW)Removing containerized worktree: $(BRANCH) ($${HASH})$(RESET)\n"; \
	echo ""; \
	\
	if podman pod inspect "$${POD_NAME}" &>/dev/null; then \
		printf "  Removing pod: $${POD_NAME}...\n"; \
		podman pod rm -f "$${POD_NAME}" 2>/dev/null || true; \
	fi; \
	\
	printf "  Removing volumes...\n"; \
	podman volume rm -f \
		"worktree-$${HASH}-pgdata" \
		"worktree-$${HASH}-node-modules" \
		"worktree-$${HASH}-mix-build" \
		"worktree-$${HASH}-mix-deps" \
		2>/dev/null || true; \
	\
	if [ -f "$${WT_DIR}/.env.secrets.resolved" ]; then \
		rm -f "$${WT_DIR}/.env.secrets.resolved"; \
	fi; \
	\
	if [ -d "$${WT_DIR}" ]; then \
		printf "  Removing git worktree...\n"; \
		if git -C "$${WT_DIR}" diff --quiet 2>/dev/null && \
		   git -C "$${WT_DIR}" diff --cached --quiet 2>/dev/null; then \
			git worktree remove "$${WT_DIR}" 2>/dev/null || \
				printf "$(YELLOW)  Warning: Could not remove worktree (may need --force)$(RESET)\n"; \
		else \
			printf "$(YELLOW)  Worktree has uncommitted changes — skipping removal$(RESET)\n"; \
			echo "  Force remove with: git worktree remove --force $${WT_DIR}"; \
		fi; \
	fi; \
	\
	bash ./infra/local/caddy-regen.sh; \
	echo ""; \
	printf "$(GREEN)Cleanup complete$(RESET)\n"

worktree-pod-list: ## List all worktree pods with status and URLs
	@printf "$(CYAN)Containerized Worktree Pods$(RESET)\n"
	@echo ""
	@PODS=$$(podman pod ls --format '{{.Name}} {{.Status}}' 2>/dev/null | grep '^worktree-' || true); \
	if [ -z "$$PODS" ]; then \
		echo "No worktree pods found"; \
		echo "Create one with: make worktree-pod-create BRANCH=feature-name"; \
	else \
		echo "$$PODS" | while read -r name status; do \
			HASH="$${name#worktree-}"; \
			BRANCH=""; \
			for wt in .worktrees/*; do \
				if [ -d "$$wt" ]; then \
					WT_BRANCH=$$(basename "$$wt"); \
					WT_HASH=$$(echo -n "$$WT_BRANCH" | $(MD5_SHORT)); \
					if [ "$$WT_HASH" = "$$HASH" ]; then \
						BRANCH="$$WT_BRANCH"; \
						break; \
					fi; \
				fi; \
			done; \
			for wt in .worktrees/*/*; do \
				if [ -d "$$wt" ]; then \
					WT_BRANCH=$$(echo "$$wt" | sed 's|^\.worktrees/||'); \
					WT_HASH=$$(echo -n "$$WT_BRANCH" | $(MD5_SHORT)); \
					if [ "$$WT_HASH" = "$$HASH" ]; then \
						BRANCH="$$WT_BRANCH"; \
						break; \
					fi; \
				fi; \
			done; \
			printf "  $(GREEN)$$name$(RESET) ($$status)\n"; \
			if [ -n "$$BRANCH" ]; then \
				printf "    Branch:    $$BRANCH\n"; \
			else \
				printf "    Branch:    $(YELLOW)unknown$(RESET)\n"; \
			fi; \
			printf "    Phoenix:   https://$$HASH.api.frontman.local\n"; \
			printf "    Vite:      https://$$HASH.vite.frontman.local\n"; \
			printf "    Next.js:   https://$$HASH.nextjs.frontman.local/frontman\n"; \
			printf "    Storybook: https://$$HASH.storybook.frontman.local\n"; \
			printf "    Marketing: https://$$HASH.marketing.frontman.local\n"; \
			echo ""; \
		done; \
	fi

worktree-pod-logs: ## Show dev container logs (BRANCH=feature/x)
	$(call require_branch,worktree-pod-logs)
	@HASH=$$(echo -n "$(BRANCH)" | $(MD5_SHORT)); \
	CONTAINER="worktree-$${HASH}-dev"; \
	if ! podman container inspect "$${CONTAINER}" &>/dev/null; then \
		printf "$(YELLOW)Error: Container $${CONTAINER} not found$(RESET)\n"; \
		exit 1; \
	fi; \
	podman logs -f "$${CONTAINER}"

## POD_END

# ============================================================================
# Release
# ============================================================================
## REL_START
.PHONY: publish publish-astro publish-vite publish-nextjs publish-swarm-ai release

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
.PHONY: kill-all-processes open-dogfooding pull-webapi debug-task

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

## UTIL_END
