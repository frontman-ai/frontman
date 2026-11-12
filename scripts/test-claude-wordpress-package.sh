#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$root/plugins/claude-wordpress"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/frontman-claude-tests.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
check="$root/scripts/check-claude-wordpress.sh"

reset_copy() {
  rm -rf "$tmp/candidate"
  cp -R "$source_dir" "$tmp/candidate"
}
reject() {
  local name=$1
  if bash "$check" "$tmp/candidate" >"$tmp/output" 2>&1; then
    echo "Expected rejection: $name" >&2
    exit 1
  fi
  printf 'Rejected %s\n' "$name"
}
change_json() {
  jq "$2" "$tmp/candidate/$1" > "$tmp/replacement"
  mv "$tmp/replacement" "$tmp/candidate/$1"
}

reset_copy
CLAUDE_CONFIG_DIR="$tmp/personal" bash "$check" "$tmp/candidate"
[ ! -e "$tmp/personal" ] || { echo "Inherited Claude config was touched" >&2; exit 1; }
bash "$root/scripts/package-claude-wordpress.sh" "$tmp/candidate" "$tmp/out"
version=$(jq -r .version "$source_dir/.claude-plugin/plugin.json")
archive="$tmp/out/frontman-claude-wordpress-v$version.zip"
test -f "$archive"
unzip -Z1 "$archive" | LC_ALL=C sort > "$tmp/files"
printf '%s\n' .claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md | LC_ALL=C sort > "$tmp/expected"
cmp "$tmp/files" "$tmp/expected"

reset_copy; echo '{' > "$tmp/candidate/.mcp.json"; reject 'invalid JSON'
reset_copy; change_json .mcp.json '.mcpServers.frontman.url = "http://api.frontman.sh/mcp"'; reject 'HTTP endpoint'
reset_copy; change_json .mcp.json '.mcpServers.frontman.url = "https://example.org/mcp"'; reject 'wrong endpoint'
reset_copy; change_json .mcp.json '.mcpServers.frontman.headers.Authorization = "secret"'; reject 'headers'
reset_copy; change_json .mcp.json '.mcpServers.other = .mcpServers.frontman'; reject 'extra server'
reset_copy; printf '{"mcpServers":{"frontman":{"type":"http","type":"http","url":"https://api.frontman.sh/mcp"}}}\n' > "$tmp/candidate/.mcp.json"; reject 'duplicate key'
reset_copy; printf '{"mcpServers":{"other":{}},"mcpServers":{"frontman":{"type":"http","url":"https://api.frontman.sh/mcp"}}}\n' > "$tmp/candidate/.mcp.json"; reject 'duplicate container with disjoint children'
reset_copy; printf '{"mcpServers":{"frontman":{"ignored":1},"frontman":{"type":"http","url":"https://api.frontman.sh/mcp"}}}\n' > "$tmp/candidate/.mcp.json"; reject 'duplicate nested container'
reset_copy; change_json .claude-plugin/plugin.json '.name = "other"'; reject 'wrong identity'
reset_copy; change_json .claude-plugin/plugin.json '.version = "1.0"'; reject 'invalid version'
reset_copy; change_json .claude-plugin/plugin.json '.extensions = {}'; reject 'unsupported manifest field'
reset_copy; change_json .claude-plugin/plugin.json '.mcpServers = {}'; reject 'duplicate manifest server'
reset_copy; change_json .claude-plugin/plugin.json '.description = "${SECRET}"'; reject 'environment interpolation'
reset_copy; printf 'sk-ant-%s\n' 'abcdefghijklmnopqrst' >> "$tmp/candidate/README.md"; reject 'dummy Anthropic key'
reset_copy; printf 'sk-proj-%s\n' 'abcdefghijklmnopqrst' >> "$tmp/candidate/README.md"; reject 'dummy project key'
reset_copy; printf 'short\n' > "$tmp/candidate/README.md"; reject 'short README'
reset_copy; { printf 'Apache-2.0\n```\n'; printf 'word %.0s' {1..60}; printf '\n```\n'; } > "$tmp/candidate/README.md"; reject 'code-only README'
reset_copy; printf 'empty\n' > "$tmp/candidate/skills/wordpress/SKILL.md"; reject 'missing skill frontmatter'
reset_copy; rm "$tmp/candidate/skills/wordpress/SKILL.md"; reject 'missing skill'
reset_copy; mkdir "$tmp/candidate/hooks"; reject 'hooks'
reset_copy; mkdir "$tmp/candidate/agents"; reject 'agents'
reset_copy; mkdir "$tmp/candidate/bin"; reject 'launcher'
reset_copy; touch "$tmp/candidate/.DS_Store"; reject 'system file'
reset_copy; touch "$tmp/candidate/credentials.json"; reject 'unexpected file'
reset_copy; ln -s README.md "$tmp/candidate/link"; reject 'symlink'
echo "Claude WordPress filesystem tests passed"
