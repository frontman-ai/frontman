ROOT := $(abspath ../..)
BUNDLE ?= $(CURDIR)
OUTPUT_DIR ?= $(ROOT)/dist/claude-wordpress
CLAUDE_BIN ?= $(ROOT)/dist/claude-wordpress-validator/claude
FILES := .claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md

export CLAUDE_CONFIG_DIR := $(ROOT)/dist/claude-wordpress-validator/config
export DISABLE_AUTOUPDATER := 1

.PHONY: toolchain check test package
toolchain:
	bash "$(ROOT)/scripts/install-claude-wordpress-validator.sh"

check:
	jq -e '.name == "frontman-wordpress"' "$(BUNDLE)/.claude-plugin/plugin.json" >/dev/null
	jq -e '. == {"mcpServers":{"frontman":{"type":"http","url":"https://api.frontman.sh/mcp"}}}' "$(BUNDLE)/.mcp.json" >/dev/null
	mkdir -p "$(CLAUDE_CONFIG_DIR)"
	"$(CLAUDE_BIN)" plugin validate --strict "$(BUNDLE)"

test:
	bash test.sh

package: check
	mkdir -p "$(OUTPUT_DIR)"
	@set -eu; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	(cd "$(BUNDLE)" && zip -q -X "$$tmp/plugin.zip" $(FILES)); \
	version=$$(jq -r .version "$(BUNDLE)/.claude-plugin/plugin.json"); \
	archive="$(OUTPUT_DIR)/frontman-claude-wordpress-v$$version.zip"; \
	mv "$$tmp/plugin.zip" "$$archive"; \
	printf 'Created %s\n' "$$archive"
