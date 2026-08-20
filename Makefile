




.DEFAULT_GOAL := help


CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m




DEVPOD_USER ?= root

define require_devpod_server
	@if [ -z "$(DEVPOD_SERVER)" ]; then \
		printf "$(YELLOW)Error: DEVPOD_SERVER is not set. Run via: op run --env-file=.env -- make $(1)$(RESET)\n"; \
		exit 1; \
	fi
endef



define require_branch
	@if [ -z "$(BRANCH)" ]; then \
		printf "$(YELLOW)Error: BRANCH is required. Usage: make $(1) BRANCH=feature-name$(RESET)\n"; \
		exit 1; \
	fi
endef




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



define run_e2e
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: test/e2e/.env not found. Copy test/e2e/.env.example and fill in values.$(RESET)\n"; exit 1; }
	set -a && . test/e2e/.env && set +a && cd test/e2e && npx vitest run $(1)
endef

.PHONY: help

HELP_SECTIONS := DEVELOPMENT BUILD SSL WT INFRA REL E2E UTIL

HELP_DEVELOPMENT_TITLE := Development
HELP_DEVELOPMENT_TARGETS := dev dev-client dev-server dev-nextjs dev-nextjs-prebuilt dev-marketing
HELP_dev := Start all core services (client + server + nextjs)
HELP_dev-client := Start development server for client app
HELP_dev-server := Start development server for server app
HELP_dev-nextjs := Start development server for Next.js test site
HELP_dev-nextjs-prebuilt := Start Next.js test site with prebuilt integration
HELP_dev-marketing := Start development server for marketing site

HELP_BUILD_TITLE := Build & Quality
HELP_BUILD_TARGETS := install hooks-install setup-elixir-tools verify-toolchain-pins build rescript-watch rescript-build rescript-format reanalyze check-source-comments mcp-conformance mcp-verify clean
HELP_install := Install dependencies
HELP_hooks-install := Install git pre-commit hooks via Lefthook
HELP_setup-elixir-tools := Install Hex/Rebar for the active mise Elixir
HELP_verify-toolchain-pins := Verify Docker Elixir image matches mise.toml
HELP_build := Build ReScript project
HELP_rescript-watch := Watch and rebuild ReScript on changes
HELP_rescript-build := Build ReScript project (one-shot)
HELP_rescript-format := Format ReScript source
HELP_reanalyze := Run ReScript dead code analysis
HELP_check-source-comments := Test scanner and check repository source comments
HELP_mcp-conformance := Run the pinned official MCP conformance scenarios
HELP_mcp-verify := Run the serial MCP aggregate verification gate
HELP_clean := Clean ReScript build artifacts

HELP_SSL_TITLE := SSL & Networking
HELP_SSL_TARGETS := ssl-setup tunnel
HELP_ssl-setup := Setup local SSL certificates using mkcert
HELP_tunnel := Start SSH tunnel to DevPod server (fallback if dnsmasq not configured)

HELP_WT_TITLE := Worktrees
HELP_WT_TARGETS := work wt wt-new wt-dev wt-stop wt-start wt-sh wt-rm wt-gc wt-urls wt-logs
HELP_work := Set up worktree from GitHub issue or PR (REF=<number|url>)
HELP_wt := Dashboard — shows all worktrees, pod status, URLs, and actions
HELP_wt-new := Create containerized worktree (BRANCH=...)
HELP_wt-dev := Start dev servers in container (BRANCH=...)
HELP_wt-stop := Pause worktree pod, preserve volumes (BRANCH=...)
HELP_wt-start := Resume a paused worktree pod (BRANCH=...)
HELP_wt-sh := Shell into dev container (BRANCH=...)
HELP_wt-rm := Full cleanup: pod + volumes + worktree (BRANCH=...)
HELP_wt-gc := Remove worktrees whose branches are merged into main
HELP_wt-urls := Show service URLs for a worktree (BRANCH=...)
HELP_wt-logs := Tail dev container logs (BRANCH=...)

HELP_INFRA_TITLE := Infrastructure
HELP_INFRA_TARGETS := infra-up infra-down infra-build
HELP_infra-up := One-time setup: dev image, Caddy, dnsmasq
HELP_infra-down := Tear down all pods, volumes, and Caddy
HELP_infra-build := Rebuild the frontman-dev container image

HELP_REL_TITLE := Release
HELP_REL_TARGETS := publish publish-astro publish-vite publish-nextjs publish-react-statestore publish-swarm-ai release package-wordpress-plugin publish-wordpress-plugin-svn test-wordpress-core-tools test-wordpress-runtime
HELP_publish := Publish all npm packages (pass OTP=<code> for 2FA)
HELP_publish-astro := Publish @frontman-ai/astro to npm (pass OTP=<code> for 2FA)
HELP_publish-vite := Publish @frontman-ai/vite to npm (pass OTP=<code> for 2FA)
HELP_publish-nextjs := Publish @frontman-ai/nextjs to npm (pass OTP=<code> for 2FA)
HELP_publish-react-statestore := Publish @frontman-ai/react-statestore to npm (pass OTP=<code> for 2FA)
HELP_publish-swarm-ai := Publish swarm_ai to Hex (dry run by default, HEX_PUBLISH=1 for real)
HELP_release := Create a release PR from pending changesets
HELP_package-wordpress-plugin := Build WordPress ZIP and WordPress.org bundle
HELP_publish-wordpress-plugin-svn := Publish WordPress.org bundle to SVN (requires WORDPRESS_ORG_* env vars)
HELP_test-wordpress-core-tools := Run PHP tests for WordPress tool implementations
HELP_test-wordpress-runtime := Run plugin integration tests in WordPress 7.0.2 containers

HELP_E2E_TITLE := E2E Tests
HELP_E2E_TARGETS := e2e mcp-blackbox e2e-nextjs e2e-astro e2e-vite e2e-vue-vite
HELP_e2e := Run all e2e tests (loads secrets from test/e2e/.env)
HELP_mcp-blackbox := Run real-process Next.js, Astro, and Vite MCP transport tests
HELP_e2e-nextjs := Run Next.js e2e test
HELP_e2e-astro := Run Astro e2e test
HELP_e2e-vite := Run Vite e2e test
HELP_e2e-vue-vite := Run Vue + Vite e2e test

HELP_UTIL_TITLE := Utilities
HELP_UTIL_TARGETS := kill-all-processes pull-webapi debug-task push
HELP_kill-all-processes := Kill all running make dev processes
HELP_pull-webapi := Pull latest experimental-rescript-webapi subtree
HELP_debug-task := Debug task interactions (ARGS="list" or ARGS="show ...")
HELP_push := Git push current branch

help:
	@printf "$(CYAN)Frontman Monorepo$(RESET)\n"
	@$(foreach section,$(HELP_SECTIONS),printf "\n$(CYAN)$(HELP_$(section)_TITLE):$(RESET)\n"; $(foreach target,$(HELP_$(section)_TARGETS),printf "  $(GREEN)%-25s$(RESET)  %s\n" "$(target)" '$(HELP_$(target))';))
	@echo ""




.PHONY: dev dev-client dev-server dev-nextjs dev-nextjs-prebuilt dev-marketing

dev:
	@printf "$(YELLOW)Starting all services via mprocs...$(RESET)\n"
	mprocs --config mprocs.yml

dev-client:
	@printf "$(YELLOW)Starting client dev server...$(RESET)\n"
	cd libs/client && $(MAKE) dev

dev-server:
	@printf "$(YELLOW)Starting server dev server...$(RESET)\n"
	cd apps/frontman_server && $(MAKE) dev

dev-nextjs:
	@printf "$(YELLOW)Starting Next.js dev server...$(RESET)\n"
	cd test/sites/blog-starter && $(MAKE) dev

dev-nextjs-prebuilt:
	@printf "$(YELLOW)Starting Next.js dev server...$(RESET)\n"
	cd test/sites/blog-starter && $(MAKE) dev-prebuilt

dev-marketing:
	@printf "$(YELLOW)Waiting for server on localhost:4000...$(RESET)\n"
	@bash -c 'while ! (: > /dev/tcp/localhost/4000) 2>/dev/null; do sleep 1; done'
	@printf "$(YELLOW)Starting marketing dev server...$(RESET)\n"
	cd apps/marketing && $(MAKE) dev




.PHONY: install build rescript-watch rescript-build rescript-format reanalyze clean hooks-install setup-elixir-tools verify-toolchain-pins check-source-comments mcp-conformance mcp-verify mcp-verify-preflight mcp-check-generated

install:
	@printf "$(YELLOW)Installing dependencies...$(RESET)\n"
	yarn install
	@$(MAKE) hooks-install

hooks-install:
	@printf "$(YELLOW)Installing git hooks...$(RESET)\n"
	@if command -v lefthook &> /dev/null; then \
		lefthook install; \
		printf "$(GREEN)Git hooks installed.$(RESET)\n"; \
	else \
		printf "$(YELLOW)lefthook not found — run 'mise install' first.$(RESET)\n"; \
	fi

setup-elixir-tools:
	@printf "$(YELLOW)Installing Hex/Rebar for mise Elixir...$(RESET)\n"
	@if ! mise exec -- mix hex.info >/dev/null 2>&1; then \
		mise exec -- mix archive.install github hexpm/hex branch latest --force; \
	fi
	@tmp=$$(mktemp -t rebar3.XXXXXX); \
	curl -fsSL "https://s3.amazonaws.com/rebar3/rebar3" -o "$$tmp"; \
	chmod +x "$$tmp"; \
	mise exec -- mix local.rebar rebar3 "$$tmp" --force; \
	rm -f "$$tmp"
	@printf "$(GREEN)Hex/Rebar ready.$(RESET)\n"

verify-toolchain-pins:
	@elixir_tool=$$(awk -F'"' '/^elixir *=/ {print $$2}' mise.toml); \
	erlang_tool=$$(awk -F'"' '/^erlang *=/ {print $$2}' mise.toml); \
	docker_image=$$(awk '/^FROM hexpm\/elixir:/ {print $$2; exit}' apps/frontman_server/Dockerfile); \
	elixir_version="$${elixir_tool%%-otp-*}"; \
	expected="hexpm/elixir:$${elixir_version}-erlang-$${erlang_tool}"; \
	if [ -z "$$elixir_tool" ] || [ -z "$$erlang_tool" ] || [ -z "$$docker_image" ]; then \
		printf "$(YELLOW)Could not read mise.toml or Dockerfile toolchain pins.$(RESET)\n"; \
		exit 1; \
	fi; \
	case "$$docker_image" in \
		$$expected*) printf "$(GREEN)Toolchain pins match: $$docker_image$(RESET)\n" ;; \
		*) printf "$(YELLOW)Toolchain pin mismatch: expected Docker image prefix '$$expected', got '$$docker_image'.$(RESET)\n"; exit 1 ;; \
	esac

build:
	@printf "$(YELLOW)Building ReScript project...$(RESET)\n"
	yarn rescript

rescript-watch:
	@printf "$(YELLOW)Starting ReScript watch mode...$(RESET)\n"
	yarn rescript watch

rescript-build:
	@printf "$(YELLOW)Starting ReScript build...$(RESET)\n"
	yarn rescript build

rescript-format:
	git ls-files -z -- '*.res' '*.resi' ':(exclude)libs/experimental-rescript-webapi/**' | xargs -0 yarn rescript format

reanalyze:
	@printf "$(YELLOW)Running ReScript dead code analysis...$(RESET)\n"
	yarn rescript-tools reanalyze

check-source-comments:
	node --test test/no-comments/no-comments.test.mjs
	node scripts/no-comments.mjs --check

mcp-conformance:
	$(MAKE) -C libs/frontman-protocol mcp-conformance

mcp-verify:
	$(MAKE) mcp-verify-preflight
	node --test test/mcp-verify/mcp-verify.test.mjs
	$(MAKE) -C libs/frontman-protocol mcp-verify
	$(MAKE) -C libs/frontman-client lint
	$(MAKE) -C libs/frontman-client test
	$(MAKE) -C libs/frontman-core lint
	$(MAKE) -C libs/frontman-core test
	$(MAKE) -C libs/frontman-nextjs lint
	$(MAKE) -C libs/frontman-nextjs test
	$(MAKE) -C libs/frontman-astro lint
	$(MAKE) -C libs/frontman-astro test
	$(MAKE) -C libs/frontman-vite lint
	$(MAKE) -C libs/frontman-vite test
	$(MAKE) -C libs/frontman-astro-browser lint
	$(MAKE) -C libs/frontman-astro-browser test
	$(MAKE) -C libs/client lint
	$(MAKE) -C libs/client test
	$(MAKE) -C libs/logs check
	$(MAKE) -C libs/react-statestore check
	$(MAKE) -C apps/swarm_ai lint
	$(MAKE) -C apps/swarm_ai test
	$(MAKE) -C apps/frontman_server lint
	$(MAKE) -C apps/frontman_server test
	$(MAKE) -C apps/frontman_notifier lint
	$(MAKE) -C apps/frontman_notifier test
	$(MAKE) -C apps/marketing test
	$(MAKE) -C apps/marketing build
	$(MAKE) test-wordpress-core-tools
	$(MAKE) test-wordpress-runtime
	$(MAKE) -C test/astro-compat test
	$(MAKE) mcp-blackbox
	$(MAKE) mcp-conformance
	$(MAKE) e2e
	$(MAKE) check-source-comments
	$(MAKE) mcp-check-generated
	@printf "$(GREEN)MCP aggregate verification passed.$(RESET)\n"

mcp-verify-preflight:
	@test -f test/e2e/.env || { printf "$(YELLOW)Error: Credentialed MCP verification is unavailable because test/e2e/.env is missing.$(RESET)\n"; exit 1; }

mcp-check-generated:
	$(MAKE) -C libs/frontman-protocol check-schemas
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; cp -R apps/frontman_server/priv/static/browser-test "$$tmp/browser-test"; cd apps/frontman_server && mix esbuild browser_test; diff -ru "$$tmp/browser-test" priv/static/browser-test

clean:
	@printf "$(YELLOW)Cleaning build artifacts...$(RESET)\n"
	yarn rescript clean





.PHONY: e2e mcp-blackbox e2e-nextjs e2e-astro e2e-vite e2e-vue-vite

e2e:
	@printf "$(YELLOW)Running all e2e tests...$(RESET)\n"
	$(call run_e2e)

mcp-blackbox:
	@printf "$(YELLOW)Building adapters and running MCP black-box tests...$(RESET)\n"
	$(MAKE) -C libs/frontman-nextjs build
	$(MAKE) -C libs/frontman-vite build
	$(MAKE) -C libs/frontman-astro build
	@VERSION=$$(bash scripts/validate-wordpress-plugin-release.sh); $(MAKE) package-wordpress-plugin VERSION="$$VERSION"
	cd test/e2e && yarn vitest run --config vitest.mcp.config.ts

e2e-nextjs:
	@printf "$(YELLOW)Running Next.js e2e test...$(RESET)\n"
	$(call run_e2e,tests/nextjs.test.ts)

e2e-astro:
	@printf "$(YELLOW)Running Astro e2e test...$(RESET)\n"
	$(call run_e2e,tests/astro.test.ts)

e2e-vite:
	@printf "$(YELLOW)Running Vite e2e test...$(RESET)\n"
	$(call run_e2e,tests/vite.test.ts)

e2e-vue-vite:
	@printf "$(YELLOW)Running Vue + Vite e2e test...$(RESET)\n"
	$(call run_e2e,tests/vue-vite.test.ts)





.PHONY: ssl-setup tunnel

ssl-setup:
	@printf "$(YELLOW)Setting up SSL certificates...$(RESET)\n"
	@mkdir -p .certs
	mkcert -install
	cd .certs && mkcert frontman.local localhost 127.0.0.1 ::1
	mv .certs/frontman.local+3.pem .certs/frontman.local.pem
	mv .certs/frontman.local+3-key.pem .certs/frontman.local-key.pem
	sudo sh -c 'grep -q frontman.local /etc/hosts || echo "127.0.0.1 frontman.local" >> /etc/hosts'

tunnel:
	$(call require_devpod_server,tunnel)
	@printf "$(YELLOW)Starting SSH tunnel to $(DEVPOD_USER)@$(DEVPOD_SERVER)$(RESET)\n"
	@echo "  Local :8080 → Remote :80 (HTTP)"
	@echo "  Local :8443 → Remote :443 (HTTPS)"
	@echo ""
	@echo "NOTE: With dnsmasq configured, you don't need this tunnel."
	@echo "Press Ctrl+C to stop the tunnel"
	ssh -L 8080:localhost:80 -L 8443:localhost:443 $(DEVPOD_USER)@$(DEVPOD_SERVER) -N






















CADDY_CONTAINER := frontman-caddy
DEV_IMAGE := frontman-dev:latest


export MD5CMD := $(shell if command -v md5sum >/dev/null 2>&1; then echo 'md5sum | cut -c1-4'; else echo 'md5 | cut -c1-4'; fi)

.PHONY: wt wt-new wt-dev wt-stop wt-start wt-sh wt-rm wt-gc wt-urls wt-logs work

work:
	@if [ -z "$(REF)" ]; then \
		printf "$(YELLOW)Usage: make work REF=<issue-number|issue-url|pr-url>$(RESET)\n"; \
		exit 1; \
	fi
	@REF="$(REF)" DEV_IMAGE=$(DEV_IMAGE) bash ./bin/work

wt:
	@bash ./bin/wt-dashboard

wt-new:
	$(call resolve_branch,wt-new)
	@BRANCH="$(BRANCH)" WORKTREE_BASE_BRANCH="$(WORKTREE_BASE_BRANCH)" DEV_IMAGE=$(DEV_IMAGE) \
		bash ./bin/wt-pod-create

wt-dev:
	$(call resolve_branch,wt-dev)
	@BRANCH="$(BRANCH)" CADDY_CONTAINER=$(CADDY_CONTAINER) \
		bash ./bin/wt-pod-dev

wt-stop:
	$(call resolve_branch,wt-stop)
	@POD=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve pod) || exit 1; \
	podman pod stop "$$POD"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Stopped. Resume with: make wt-start BRANCH=$(BRANCH)$(RESET)\n"

wt-start:
	$(call resolve_branch,wt-start)
	@POD=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve pod) || exit 1; \
	podman pod start "$$POD"; \
	bash ./infra/local/caddy-regen.sh; \
	printf "$(GREEN)Started. Run: make wt-dev BRANCH=$(BRANCH)$(RESET)\n"

wt-sh:
	$(call resolve_branch,wt-sh)
	@CONTAINER=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve container) || exit 1; \
	podman exec -it -w /workspaces/frontman "$$CONTAINER" bash

wt-rm:
	$(call resolve_branch,wt-rm)
	@BRANCH="$(BRANCH)" bash ./bin/wt-pod-remove

wt-gc:
	@bash ./bin/wt-gc

wt-urls:
	$(call resolve_branch,wt-urls)
	@HASH=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve hash); \
	echo ""; \
	printf "$(CYAN)$(BRANCH) ($$HASH)$(RESET)\n"; \
	echo ""; \
	printf "  $(GREEN)Phoenix$(RESET)     https://$$HASH.api.frontman.local\n"; \
	printf "  $(GREEN)Vite$(RESET)        https://$$HASH.vite.frontman.local\n"; \
	printf "  $(GREEN)Next.js$(RESET)     https://$$HASH.nextjs.frontman.local/frontman\n"; \
	printf "  $(GREEN)Marketing$(RESET)   https://$$HASH.marketing.frontman.local\n"; \
	echo ""

wt-logs:
	$(call resolve_branch,wt-logs)
	@CONTAINER=$$(BRANCH="$(BRANCH)" bash ./bin/wt-resolve container) || exit 1; \
	podman logs -f "$$CONTAINER"





.PHONY: infra-up infra-down infra-build

infra-up:
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

infra-down:
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

infra-build:
	@podman build -t $(DEV_IMAGE) -f .devcontainer/Dockerfile .devcontainer/





.PHONY: worktree-create worktree-list worktree-remove worktree-clean \
        worktree-register worktree-registry



worktree-create:
	$(call require_branch,worktree-create)
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|^origin/||'); \
	WORKTREE_BASE_BRANCH=$${WORKTREE_BASE_BRANCH:-$(shell git branch --show-current)}; \
	mkdir -p .worktrees; \
	if git show-ref --verify --quiet "refs/heads/$$WORKTREE_NAME" || \
	   git show-ref --verify --quiet "refs/remotes/origin/$$WORKTREE_NAME" || \
	   git show-ref --verify --quiet "refs/remotes/$(BRANCH)"; then \
		git worktree add ".worktrees/$$WORKTREE_NAME" $(BRANCH); \
	else \
		if [ -n "$$WORKTREE_BASE_BRANCH" ]; then \
			git worktree add ".worktrees/$$WORKTREE_NAME" -b "$$WORKTREE_NAME" "$$WORKTREE_BASE_BRANCH"; \
		else \
			git worktree add ".worktrees/$$WORKTREE_NAME" -b "$$WORKTREE_NAME"; \
		fi; \
	fi; \
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




.PHONY: publish publish-astro publish-vite publish-nextjs publish-react-statestore publish-swarm-ai release package-wordpress-plugin publish-wordpress-plugin-svn test-wordpress-core-tools

publish: publish-astro publish-vite publish-nextjs publish-react-statestore

publish-astro:
	cd libs/frontman-astro && $(MAKE) publish OTP=$(OTP)

publish-vite:
	cd libs/frontman-vite && $(MAKE) publish OTP=$(OTP)

publish-nextjs:
	cd libs/frontman-nextjs && $(MAKE) publish OTP=$(OTP)

publish-react-statestore:
	cd libs/react-statestore && $(MAKE) publish OTP=$(OTP)

publish-swarm-ai:
	cd apps/swarm_ai && $(MAKE) hex-publish HEX_PUBLISH=$(HEX_PUBLISH)

release:
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
	@printf "$(CYAN)Validating changesets...$(RESET)\n"
	@yarn changeset status
	@printf "$(YELLOW)Triggering release workflow...$(RESET)\n"
	@gh workflow run release-pr.yml --ref main
	@printf "$(GREEN)Release workflow triggered.$(RESET)\n"
	@echo "Watch for the PR at: https://github.com/frontman-ai/frontman/pulls"

package-wordpress-plugin:
	@VERSION=$(VERSION) bash ./scripts/package-wordpress-plugin.sh

publish-wordpress-plugin-svn: package-wordpress-plugin
	@VERSION=$(VERSION) bash ./scripts/publish-wordpress-plugin-svn.sh

test-wordpress-core-tools:
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/NoFilesystemToolsTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/ElementorToolsTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/MediaToolsTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/WooCommerceToolsTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/MutationSnapshotsTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/PluginDependenciesTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/McpTest.php
	@php -d auto_prepend_file=libs/frontman-wordpress/tests/ErrorHandler.php libs/frontman-wordpress/tests/RouterTest.php

test-wordpress-runtime:
	@bash scripts/test-wordpress-plugin-runtime.sh





.PHONY: kill-all-processes pull-webapi debug-task push

kill-all-processes:
	@ps aux | grep "[m]ake dev" | awk '{print $$2}' | xargs -r kill 2>/dev/null || true

pull-webapi:
	git subtree pull --prefix libs/experimental-rescript-webapi https://github.com/rescript-lang/experimental-rescript-webapi.git main --squash

debug-task:
	cd apps/frontman_server && $(MAKE) debug-task ARGS="$(ARGS)"

push:
	@git push
