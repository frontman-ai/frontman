.DEFAULT_GOAL := help
.PHONY: help install build clean dev test lint dev-client dev-nextjs pull-webapi infra-install infra-preview-marketing infra-up-marketing ssl-setup worktree-create worktree-create-from worktree-list worktree-remove worktree-clean worktree-status

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build ReScript project
	yarn rescript

clean: ## Clean build artifacts
	yarn rescript clean

dev: ## Watch and rebuild on changes
	yarn rescript watch

test: ## Run tests
	# Add test commands here

lint: ## Run linters
	# Add lint commands here

dev-client: ## Start development server for client app
	cd libs/client && $(MAKE) dev

dev-server: ## Start development server for server app
	cd apps/frontman_server && $(MAKE) dev

dev-nextjs: ## Start development server for Next.js test site
	cd test/sites/blog-starter && $(MAKE) dev

dev-extension: ## Start development server for Chrome extension
	cd apps/chrome-extension && $(MAKE) dev

pull-webapi: ## Pull latest changes from experimental-rescript-webapi subtree
	git subtree pull --prefix libs/experimental-rescript-webapi git@github.com:itayadler/experimental-rescript-webapi.git main --squash

kill-all-processes: ## Kill all processes
	ps aux | grep "make dev" | awk -F ' ' '{print $$2}' | xargs kill

dev-dogfooding: ## Start development server for dogfooding app
	cd apps/dogfooding && npm install && $(MAKE) dev

dev-marketing: ## Start development server for marketing site
	cd apps/marketing && $(MAKE) dev

ssl-setup: ## Setup local SSL certificates using mkcert
	@mkdir -p .certs
	mkcert -install
	cd .certs && mkcert frontman.local localhost 127.0.0.1 ::1
	mv .certs/frontman.local+3.pem .certs/frontman.local.pem
	mv .certs/frontman.local+3-key.pem .certs/frontman.local-key.pem
	sudo sh -c 'grep -q frontman.local /etc/hosts || echo "127.0.0.1 frontman.local" >> /etc/hosts'

open-dogfooding: ## Open dogfooding app in browser
	open -n -a "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security http://localhost:6123

infra-install: ## Install infrastructure dependencies
	cd infra && $(MAKE) install

infra-preview-marketing: ## Preview marketing infrastructure changes
	cd infra && $(MAKE) preview-marketing

infra-up-marketing: ## Deploy marketing infrastructure
	cd infra && $(MAKE) up-marketing

worktree-create: ## Create a new worktree (usage: make worktree-create BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		echo "Error: BRANCH is required. Usage: make worktree-create BRANCH=feature-name"; \
		exit 1; \
	fi
	@if git show-ref --verify --quiet refs/heads/$(BRANCH); then \
		echo "Error: Branch '$(BRANCH)' already exists locally"; \
		echo "Use 'make worktree-create-from BRANCH=$(BRANCH)' to create a worktree from it"; \
		exit 1; \
	fi
	@echo "Creating worktree for new branch: $(BRANCH)"
	@mkdir -p .worktrees
	@git worktree add .worktrees/$(BRANCH) -b $(BRANCH)
	@mkdir -p .worktrees/$(BRANCH)/.claude/projects .worktrees/$(BRANCH)/.claude/plans .worktrees/$(BRANCH)/.claude/todos
	@touch .worktrees/$(BRANCH)/.claude/history.jsonl
	@echo "Worktree created at: .worktrees/$(BRANCH)"
	@echo "Next steps:"
	@echo "  1. cd .worktrees/$(BRANCH)"
	@echo "  2. make install"

worktree-create-from: ## Create worktree from existing branch (usage: make worktree-create-from BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		echo "Error: BRANCH is required"; \
		echo "Usage: make worktree-create-from BRANCH=origin/feature-name"; \
		exit 1; \
	fi
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|^origin/||'); \
	echo "Creating worktree from: $(BRANCH) as $$WORKTREE_NAME"; \
	mkdir -p .worktrees; \
	git worktree add .worktrees/$$WORKTREE_NAME $(BRANCH); \
	mkdir -p .worktrees/$$WORKTREE_NAME/.claude/projects .worktrees/$$WORKTREE_NAME/.claude/plans .worktrees/$$WORKTREE_NAME/.claude/todos; \
	touch .worktrees/$$WORKTREE_NAME/.claude/history.jsonl; \
	echo "Worktree created at: .worktrees/$$WORKTREE_NAME"; \
	echo "Next steps:"; \
	echo "  1. cd .worktrees/$$WORKTREE_NAME"; \
	echo "  2. make install"

worktree-list: ## List all worktrees
	@echo "Active worktrees:"
	@git worktree list

worktree-remove: ## Remove a worktree (usage: make worktree-remove BRANCH=feature-name)
	@if [ -z "$(BRANCH)" ]; then \
		echo "Error: BRANCH is required. Usage: make worktree-remove BRANCH=feature-name"; \
		exit 1; \
	fi
	@if [ ! -d ".worktrees/$(BRANCH)" ]; then \
		echo "Error: Worktree '.worktrees/$(BRANCH)' does not exist"; \
		exit 1; \
	fi
	@echo "Removing worktree: $(BRANCH)"
	@if git -C .worktrees/$(BRANCH) diff --quiet && git -C .worktrees/$(BRANCH) diff --cached --quiet; then \
		git worktree remove .worktrees/$(BRANCH); \
		echo "Worktree removed"; \
	else \
		echo "Error: Worktree has uncommitted changes"; \
		echo "Commit or stash changes first, or force remove with:"; \
		echo "  git worktree remove --force .worktrees/$(BRANCH)"; \
		exit 1; \
	fi

worktree-clean: ## Remove all stale worktrees
	@echo "Cleaning stale worktrees..."
	@git worktree prune
	@echo "Done"

worktree-status: ## Show status of all worktrees
	@echo "Worktree Status:"
	@echo ""
	@if [ ! -d ".worktrees" ] || [ -z "$$(ls -A .worktrees 2>/dev/null)" ]; then \
		echo "No worktrees found in .worktrees/"; \
	else \
		for wt in .worktrees/*; do \
			if [ -d "$$wt" ]; then \
				branch=$$(git -C "$$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
				echo "$$(basename $$wt) ($$branch):"; \
				git -C "$$wt" status -s || true; \
				echo ""; \
			fi \
		done; \
	fi
