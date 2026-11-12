#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$source_dir" "$tmp/candidate"

CLAUDE_CONFIG_DIR="$tmp/personal" make -C "$source_dir" package BUNDLE="$tmp/candidate" OUTPUT_DIR="$tmp/out"
test ! -e "$tmp/personal"
version=$(jq -r .version "$source_dir/.claude-plugin/plugin.json")
archive="$tmp/out/frontman-claude-wordpress-v$version.zip"
unzip -Z1 "$archive" | LC_ALL=C sort > "$tmp/actual"
printf '%s\n' .claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md | LC_ALL=C sort > "$tmp/expected"
cmp "$tmp/actual" "$tmp/expected"
unzip -q "$archive" -d "$tmp/extracted"
for file in .claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md; do
  cmp "$source_dir/$file" "$tmp/extracted/$file"
done
make -C "$source_dir" check BUNDLE="$tmp/extracted"

for change in \
  '.mcpServers.frontman.url = "https://example.org/mcp"' \
  '.mcpServers.frontman.headers.Authorization = "test-only"' \
  '.mcpServers.other = .mcpServers.frontman'; do
  jq "$change" "$source_dir/.mcp.json" > "$tmp/candidate/.mcp.json"
  if make -C "$source_dir" check BUNDLE="$tmp/candidate" > "$tmp/output" 2>&1; then
    cat "$tmp/output" >&2
    echo "Unexpected MCP configuration accepted: $change" >&2
    exit 1
  fi
done
echo "Claude plugin endpoint and package checks passed"
