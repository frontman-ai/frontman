.DEFAULT_GOAL := help
.PHONY: help install test seo-monitor dev build deploy indexnow blog-cover

PORT ?= 4321
DAYS ?= 14

HELP_TARGETS := help install test seo-monitor dev build deploy indexnow blog-cover
HELP_help := Display available commands
HELP_install := Install dependencies
HELP_test := Run marketing tests
HELP_seo-monitor := Compare Google organic periods — END_DATE=YYYY-MM-DD [DAYS=14]
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

seo-monitor:
	@test -n "$(END_DATE)" || (echo "Usage: make seo-monitor END_DATE=YYYY-MM-DD [DAYS=14]" >&2; exit 1)
	@python3 -B scripts/seo_monitor.py --end-date "$(END_DATE)" --days "$(DAYS)"

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
