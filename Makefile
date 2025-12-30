.DEFAULT_GOAL := help
.PHONY: help install build clean dev test lint dev-client dev-nextjs pull-webapi infra-install infra-preview-marketing infra-up-marketing worktree-create worktree-create-from worktree-list worktree-remove worktree-clean worktree-status

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
	@echo "Creating worktree for branch: $(BRANCH)"
	@git worktree add .worktrees/$(BRANCH) -b $(BRANCH)
	@echo "Setting up Claude Code context..."
	@mkdir -p .worktrees/$(BRANCH)/.claude/projects
	@mkdir -p .worktrees/$(BRANCH)/.claude/plans
	@mkdir -p .worktrees/$(BRANCH)/.claude/todos
	@ln -sf ~/.claude/CLAUDE.md .worktrees/$(BRANCH)/.claude/
	@ln -sf ~/.claude/docs .worktrees/$(BRANCH)/.claude/
	@ln -sf ~/.claude/agents .worktrees/$(BRANCH)/.claude/
	@ln -sf ~/.claude/commands .worktrees/$(BRANCH)/.claude/
	@touch .worktrees/$(BRANCH)/.claude/history.jsonl
	@echo "Linking dependencies..."
	@ln -sf $(PWD)/node_modules .worktrees/$(BRANCH)/
	@echo "Worktree created at: .worktrees/$(BRANCH)"
	@echo "Next steps:"
	@echo "  1. cd .worktrees/$(BRANCH)"
	@echo "  2. make install  # Install any branch-specific deps"
	@echo "  3. Open in Claude Code"

worktree-create-from: ## Create worktree from existing branch (usage: make worktree-create-from BRANCH=origin/feature NAME=local-name)
	@if [ -z "$(BRANCH)" ] || [ -z "$(NAME)" ]; then \
		echo "Error: BRANCH and NAME required"; \
		echo "Usage: make worktree-create-from BRANCH=origin/feature NAME=feature"; \
		exit 1; \
	fi
	@echo "Creating worktree from: $(BRANCH)"
	@git worktree add .worktrees/$(NAME) $(BRANCH)
	@mkdir -p .worktrees/$(NAME)/.claude/projects
	@mkdir -p .worktrees/$(NAME)/.claude/plans
	@mkdir -p .worktrees/$(NAME)/.claude/todos
	@ln -sf ~/.claude/CLAUDE.md .worktrees/$(NAME)/.claude/
	@ln -sf ~/.claude/docs .worktrees/$(NAME)/.claude/
	@ln -sf ~/.claude/agents .worktrees/$(NAME)/.claude/
	@ln -sf ~/.claude/commands .worktrees/$(NAME)/.claude/
	@touch .worktrees/$(NAME)/.claude/history.jsonl
	@ln -sf $(PWD)/node_modules .worktrees/$(NAME)/
	@echo "Worktree created at: .worktrees/$(NAME)"

worktree-list: ## List all worktrees
	@echo "Active worktrees:"
	@git worktree list

worktree-remove: ## Remove a worktree (usage: make worktree-remove NAME=feature-name)
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME is required"; \
		exit 1; \
	fi
	@echo "Removing worktree: $(NAME)"
	@if git -C .worktrees/$(NAME) diff --quiet && git -C .worktrees/$(NAME) diff --cached --quiet; then \
		git worktree remove --force .worktrees/$(NAME); \
		echo "Worktree removed"; \
	else \
		echo "Error: Worktree has uncommitted changes"; \
		echo "Commit changes first, or use: git worktree remove -f .worktrees/$(NAME)"; \
		exit 1; \
	fi

worktree-clean: ## Remove all stale worktrees
	@echo "Cleaning stale worktrees..."
	@git worktree prune
	@echo "Done"

worktree-status: ## Show status of all worktrees
	@echo "Worktree Status:"
	@echo ""
	@for wt in .worktrees/*; do \
		if [ -d "$$wt" ]; then \
			echo "$$(basename $$wt):"; \
			git -C "$$wt" status -s || true; \
			echo ""; \
		fi \
	done
