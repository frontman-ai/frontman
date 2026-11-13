ROOT := $(abspath ../..)
OUTPUT_DIR ?= $(ROOT)/dist/claude-wordpress
CLAUDE_BIN ?= claude
FILES := .claude-plugin/plugin.json .claude-plugin/icon.png .mcp.json skills/wordpress/SKILL.md README.md

.PHONY: check package
check:
	"$(CLAUDE_BIN)" plugin validate --strict "$(CURDIR)"

package: check
	mkdir -p "$(OUTPUT_DIR)"
	@set -eu; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	zip -q -X "$$tmp/plugin.zip" $(FILES); \
	version=$$(jq -r .version .claude-plugin/plugin.json); \
	archive="$(OUTPUT_DIR)/frontman-claude-wordpress-v$$version.zip"; \
	mv "$$tmp/plugin.zip" "$$archive"; \
	printf 'Created %s\n' "$$archive"
