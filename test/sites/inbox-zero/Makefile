.DEFAULT_GOAL := help
.PHONY: help install dev build test start clean db-up db-down db-create db-migrate db-reset lint format check subtree-pull subtree-status subtree-diff

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

# Variables
SHELL := /bin/bash
export PATH := $(shell echo $$HOME/.local/share/mise/installs/pnpm/10.19.0):$(PATH)

# Subtree configuration
SUBTREE_PREFIX := test/sites/inbox-zero
SUBTREE_REMOTE := inbox-zero-upstream
SUBTREE_BRANCH := main

help: ## Display available commands
	@printf "$(CYAN)Available commands:$(RESET)\n"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

install: ## Install dependencies with pnpm
	@printf "$(YELLOW)Installing dependencies...$(RESET)\n"
	pnpm install

dev: ## Start development server (Turborepo)
	@printf "$(YELLOW)Starting development server...$(RESET)\n"
	pnpm run dev

build: ## Build for production
	@printf "$(YELLOW)Building project...$(RESET)\n"
	pnpm run build

test: ## Run tests
	@printf "$(YELLOW)Running tests...$(RESET)\n"
	pnpm run test

start: ## Start production server
	@printf "$(YELLOW)Starting production server...$(RESET)\n"
	pnpm start

db-up: ## Start PostgreSQL and Redis with Docker
	@printf "$(YELLOW)Starting database services...$(RESET)\n"
	docker-compose up -d

db-down: ## Stop database services
	@printf "$(YELLOW)Stopping database services...$(RESET)\n"
	docker-compose down

db-create: ## Create the inboxzero database
	@printf "$(YELLOW)Creating inboxzero database...$(RESET)\n"
	docker exec inbox-zero psql -U postgres -c "CREATE DATABASE inboxzero;" || echo "Database may already exist"

db-migrate: ## Run database migrations
	@printf "$(YELLOW)Running migrations...$(RESET)\n"
	cd apps/web && pnpm prisma migrate dev

db-reset: ## Reset database (drop, create, migrate)
	@printf "$(YELLOW)Resetting database...$(RESET)\n"
	docker exec inbox-zero psql -U postgres -c "DROP DATABASE IF EXISTS inboxzero;"
	docker exec inbox-zero psql -U postgres -c "CREATE DATABASE inboxzero;"
	cd apps/web && pnpm prisma migrate dev

lint: ## Run linter
	@printf "$(YELLOW)Running linter...$(RESET)\n"
	pnpm run lint

format: ## Format and lint code
	@printf "$(YELLOW)Formatting and linting code...$(RESET)\n"
	pnpm run format-and-lint:fix

check: ## Run format check and linter
	@printf "$(YELLOW)Running checks...$(RESET)\n"
	pnpm run format-and-lint

clean: ## Clean build artifacts
	@printf "$(YELLOW)Cleaning up...$(RESET)\n"
	rm -rf .next .turbo node_modules apps/*/node_modules packages/*/node_modules

subtree-pull: ## Pull latest changes from upstream inbox-zero
	@printf "$(YELLOW)Pulling latest changes from upstream...$(RESET)\n"
	cd ../.. && git subtree pull --prefix $(SUBTREE_PREFIX) $(SUBTREE_REMOTE) $(SUBTREE_BRANCH) --squash

subtree-status: ## Show status of this subtree
	@printf "$(CYAN)Subtree Information:$(RESET)\n"
	@printf "  Prefix: $(GREEN)$(SUBTREE_PREFIX)$(RESET)\n"
	@printf "  Remote: $(GREEN)$(SUBTREE_REMOTE)$(RESET)\n"
	@printf "  Branch: $(GREEN)$(SUBTREE_BRANCH)$(RESET)\n"
	@echo ""
	@printf "$(CYAN)Last subtree commit:$(RESET)\n"
	@cd ../.. && git log --grep="git-subtree-dir: $(SUBTREE_PREFIX)" --oneline -1

subtree-diff: ## Show diff between local and upstream
	@printf "$(YELLOW)Fetching upstream changes...$(RESET)\n"
	@cd ../.. && git fetch $(SUBTREE_REMOTE) $(SUBTREE_BRANCH)
	@printf "$(CYAN)Commits in upstream not in local:$(RESET)\n"
	@cd ../.. && git log HEAD..$(SUBTREE_REMOTE)/$(SUBTREE_BRANCH) --oneline -- $(SUBTREE_PREFIX) || echo "No new commits"
