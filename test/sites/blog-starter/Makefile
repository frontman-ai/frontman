.DEFAULT_GOAL := help
.PHONY: help install frontman-nextjs dev dev-prebuilt dev-ssl debug build start clean

FRONTMAN_NEXTJS_DIR := ../../../libs/frontman-nextjs

HELP_TARGETS := help install frontman-nextjs dev dev-prebuilt dev-ssl debug build start clean
HELP_help := Display available commands
HELP_install := Install dependencies
HELP_frontman-nextjs := Build local Frontman Next.js package
HELP_dev := Build Frontman and start development server with Turbopack
HELP_dev-prebuilt := Start development server with prebuilt Frontman package
HELP_dev-ssl := Build Frontman and start development server with HTTPS
HELP_debug := Build Frontman and start development server with Node inspector
HELP_build := Build Frontman and production site
HELP_start := Start production server
HELP_clean := Clean build artifacts

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	npm install

frontman-nextjs:
	$(MAKE) -C $(FRONTMAN_NEXTJS_DIR) build

dev: frontman-nextjs
	$(MAKE) dev-prebuilt

dev-prebuilt:
	npm run dev

dev-ssl: frontman-nextjs
	npm run dev:ssl

debug: frontman-nextjs
	npm run debug

build: frontman-nextjs
	npm run build

start:
	npm run start

clean:
	rm -rf .next
