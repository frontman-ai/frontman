.DEFAULT_GOAL := help
.PHONY: help install frontman-nextjs dev dev-prebuilt dev-ssl debug build start clean

FRONTMAN_NEXTJS_DIR := ../../../libs/frontman-nextjs

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	npm install

frontman-nextjs: ## Build local Frontman Next.js package
	$(MAKE) -C $(FRONTMAN_NEXTJS_DIR) build

dev: frontman-nextjs ## Build Frontman and start development server with Turbopack
	$(MAKE) dev-prebuilt

dev-prebuilt: ## Start development server with prebuilt Frontman package
	npm run dev

dev-ssl: frontman-nextjs ## Build Frontman and start development server with HTTPS
	npm run dev:ssl

debug: frontman-nextjs ## Build Frontman and start development server with Node inspector
	npm run debug

build: frontman-nextjs ## Build Frontman and production site
	npm run build

start: ## Start production server
	npm run start

clean: ## Clean build artifacts
	rm -rf .next
