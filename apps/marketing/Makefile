.DEFAULT_GOAL := help
.PHONY: help install test test-rendered test-browser dev build deploy indexnow blog-cover

PORT ?= 4321
RENDERED_TESTS ?= test/*.test.ts

HELP_TARGETS := help install test test-rendered test-browser dev build deploy indexnow blog-cover
HELP_help := Display available commands
HELP_install := Install dependencies
HELP_test := Run marketing tests
HELP_test-rendered := Build and test production HTML
HELP_test-browser := Build and test production pages in Chromium
HELP_dev := Start development server
HELP_build := Build for production
HELP_deploy := Build and deploy to Cloudflare Pages
HELP_indexnow := Submit sitemap URLs through IndexNow
HELP_blog-cover := Generate blog cover image — usage: make blog-cover TITLE="Your Title" [FILE=output-name]

help:
	@$(foreach target,$(HELP_TARGETS),printf "  %-15s  %s\n" "$(target)" '$(HELP_$(target))';)

install:
	yarn install

test:
	yarn run -T vitest run src/integrations/*.test.ts src/integrations/*.test.mjs src/content/*.test.mjs src/utils/*.test.mjs

test-rendered: build
	# Multi-page DOM checks parse the full production stylesheets as well as the HTML.
	yarn run -T vitest run --maxWorkers=2 --testTimeout=30000 $(RENDERED_TESTS)

test-browser: build
	yarn run -T vitest run test/browser/*.test.ts

dev:
	yarn dev --port $(PORT)

build:
	yarn build

deploy: build
	op run --env-file=../../.env -- npx wrangler pages deploy dist --project-name=frontman-marketing --branch=main

indexnow: build
	node scripts/indexnow.mjs

blog-cover:
	@test -n "$(TITLE)" || (echo "Usage: make blog-cover TITLE=\"Your Title\" [FILE=output-name]" && exit 1)
	node scripts/generate-blog-cover.mjs "$(TITLE)" $(FILE)
